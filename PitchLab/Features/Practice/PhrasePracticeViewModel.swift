import AVFoundation
import Combine
import Foundation

@MainActor
final class PhrasePracticeViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case countdown(Int)
        case recording
        case finished
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var microphoneStatus: MicrophonePitchService.Status = .idle
    @Published private(set) var currentHz: Double?
    @Published private(set) var readings: [TimedPitchReading] = []
    @Published private(set) var feedback: PhraseFeedback?

    private let microphone = MicrophonePitchService()
    private let player = TonePlayer()
    private var subscriptions = Set<AnyCancellable>()
    private var attemptTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var score: VocalScore?
    private var phrase: VocalPhrase?
    private var transposition = 0
    private var awaitingMicrophone = false
    private var recordingStart: TimeInterval = 0

    var currentName: String {
        currentHz.flatMap(NoteMath.nearestMIDINote(frequency:)).map(NoteMath.name(midi:)) ?? "—"
    }

    init() {
        microphone.$status.sink { [weak self] status in
            guard let self else { return }
            self.microphoneStatus = status
            if status == .listening, self.awaitingMicrophone {
                self.awaitingMicrophone = false
                self.startCountdown()
            }
        }.store(in: &subscriptions)
        microphone.$pitchHz.sink { [weak self] hz in
            guard let self else { return }
            self.currentHz = hz
            guard self.phase == .recording, let phrase = self.phrase else { return }
            let elapsed = ProcessInfo.processInfo.systemUptime - self.recordingStart
            self.readings.append(TimedPitchReading(time: phrase.start + elapsed, frequency: hz))
        }.store(in: &subscriptions)
    }

    func begin(score: VocalScore, phrase: VocalPhrase, transposition: Int) {
        stop()
        self.score = score
        self.phrase = phrase
        self.transposition = transposition
        feedback = nil
        readings = []
        awaitingMicrophone = true
        microphone.start()
        if microphone.status == .listening, awaitingMicrophone {
            awaitingMicrophone = false
            startCountdown()
        }
    }

    func preview(score: VocalScore, phrase: VocalPhrase, transposition: Int) {
        stop()
        feedback = nil
        readings = []
        previewTask = Task { [weak self] in
            guard let self else { return }
            var elapsed = 0.0
            for index in phrase.noteRange where score.notes.indices.contains(index) {
                guard !Task.isCancelled else { break }
                let note = score.notes[index]
                let noteStart = note.onset - phrase.start
                let gap = max(0, noteStart - elapsed)
                if gap > 0 { try? await Task.sleep(for: .seconds(gap)) }
                guard !Task.isCancelled else { break }
                let midi = note.midi + transposition
                player.noteOn(midi: midi)
                try? await Task.sleep(for: .seconds(max(0.05, note.duration)))
                player.noteOff(midi: midi)
                elapsed = noteStart + note.duration
            }
            player.stopAll()
            previewTask = nil
        }
    }

    func stop() {
        attemptTask?.cancel()
        attemptTask = nil
        previewTask?.cancel()
        previewTask = nil
        awaitingMicrophone = false
        phase = .idle
        microphone.stop()
        player.stopAll()
    }

    private func startCountdown() {
        guard phrase != nil else { return }
        attemptTask = Task { [weak self] in
            guard let self else { return }
            for count in (1...3).reversed() {
                guard !Task.isCancelled else { return }
                phase = .countdown(count)
                try? await Task.sleep(for: .seconds(1))
            }
            guard !Task.isCancelled, let phrase else { return }
            readings = []
            recordingStart = ProcessInfo.processInfo.systemUptime
            phase = .recording
            try? await Task.sleep(for: .seconds(max(0.2, phrase.end - phrase.start + 0.15)))
            guard !Task.isCancelled else { return }
            finish()
        }
    }

    private func finish() {
        phase = .finished
        microphone.stop()
        if let score, let phrase {
            feedback = PhraseScoring.evaluate(score: score, phrase: phrase,
                                              readings: readings, transposition: transposition)
        }
        attemptTask = nil
    }
}
