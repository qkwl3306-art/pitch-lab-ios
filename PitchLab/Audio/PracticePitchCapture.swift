import AVFoundation
import Combine

@MainActor
protocol PracticePitchCapture: AnyObject {
    var status: MicrophonePitchService.Status { get }
    var statusPublisher: AnyPublisher<MicrophonePitchService.Status, Never> { get }
    var pitchPublisher: AnyPublisher<Double?, Never> { get }
    func start(mode: AVAudioSession.Mode?)
    func stop()
}

extension MicrophonePitchService: PracticePitchCapture {
    var statusPublisher: AnyPublisher<Status, Never> { $status.eraseToAnyPublisher() }
    var pitchPublisher: AnyPublisher<Double?, Never> { $pitchHz.eraseToAnyPublisher() }
}
