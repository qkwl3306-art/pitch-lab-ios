import AVFoundation
import Combine
import Foundation

@MainActor
final class MicrophonePitchService: ObservableObject {
    enum Status: Equatable {
        case idle
        case requestingPermission
        case listening
        case denied
        case interrupted
        case failed(String)
    }

    @Published private(set) var pitchHz: Double?
    @Published private(set) var status: Status = .idle

    private let engine = AVAudioEngine()
    private let analysisQueue = DispatchQueue(label: "PitchLab.pitch-analysis", qos: .userInitiated)
    private let analysisGate = AudioAnalysisGate()
    private var captureIntent = CaptureIntent()
    private var tapInstalled = false
    private var interruptionObserver: NSObjectProtocol?
    private var captureMode: AVAudioSession.Mode = .measurement

    init() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let kind = AVAudioSession.InterruptionType(rawValue: raw) else { return }
                if kind == .began, self.status == .listening {
                    self.stop()
                    self.status = .interrupted
                } else if kind == .ended, self.status == .interrupted {
                    self.start()
                }
            }
        }
    }

    func start(mode: AVAudioSession.Mode? = nil) {
        if let mode { captureMode = mode }
        guard status != .listening, status != .requestingPermission else { return }
        let request = captureIntent.begin()
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            startEngine(request: request)
        case .denied:
            status = .denied
        case .undetermined:
            status = .requestingPermission
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    guard self.captureIntent.isCurrent(request) else { return }
                    if granted { self.startEngine(request: request) } else { self.status = .denied }
                }
            }
        @unknown default:
            status = .failed("无法读取麦克风权限状态")
        }
    }

    func stop() {
        captureIntent.cancel()
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        pitchHz = nil
        status = .idle
    }

    private func startEngine(request: Int) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: captureMode, options: [.defaultToSpeaker])
            if captureMode == .default, #available(iOS 18.0, *), session.isEchoCancelledInputAvailable {
                try? session.setPrefersEchoCancelledInput(true)
            }
            try session.setActive(true)
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                status = .failed("未找到可用的麦克风输入")
                return
            }
            let gate = analysisGate
            let worker = analysisQueue
            input.installTap(onBus: 0, bufferSize: 4_096, format: format) { [weak self] buffer, _ in
                guard gate.begin() else { return }
                guard let channel = buffer.floatChannelData?[0] else {
                    gate.end()
                    return
                }
                let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
                worker.async {
                    let hz = PitchDetector.detect(samples: samples, sampleRate: format.sampleRate)
                    gate.end()
                    Task { @MainActor [weak self] in
                        guard let self, self.captureIntent.isCurrent(request), self.status == .listening else { return }
                        self.pitchHz = hz
                    }
                }
            }
            tapInstalled = true
            engine.prepare()
            try engine.start()
            status = .listening
        } catch {
            stop()
            status = .failed(error.localizedDescription)
        }
    }
}
