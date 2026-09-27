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
    private var scoringReadings: [TimedPitchReading] = []
    private var displayLimiter = PitchDisplayLimiter()
    private var subscriptions = Set<AnyCancellable>()
    private var attemptTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var phraseRenderTask: Task<[Float], Never>?
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
            let now = ProcessInfo.processInfo.systemUptime
            if self.phase == .recording, let phrase = self.phrase {
                let elapsed = now - self.recordingStart
                self.scoringReadings.append(TimedPitchReading(time: phrase.start + elapsed, frequency: hz))
            }
            guard self.displayLimiter.shouldPublish(at: now) else { return }
            self.currentHz = hz
            guard self.phase == .recording, let phrase = self.phrase else { return }
            let elapsed = now - self.recordingStart
            let reading = TimedPitchReading(time: phrase.start + elapsed, frequency: hz)
            if self.readings.count == 256 { self.readings.removeFirst() }
            self.readings.append(reading)
        }.store(in: &subscriptions)
    }

    func begin(score: VocalScore, phrase: VocalPhrase, transposition: Int) {
        stop()
        self.score = score
        self.phrase = phrase
        self.transposition = transposition
        feedback = nil
        resetReadings()
        let events = Self.events(score: score, phrase: phrase, transposition: transposition)
        phraseRenderTask = Task.detached(priority: .userInitiated) {
            ToneSequenceRenderer.render(events: events)
        }
        awaitingMicrophone = true
        microphone.start(mode: .default)
        if microphone.status == .listening, awaitingMicrophone {
            awaitingMicrophone = false
            startCountdown()
        }
    }

    func preview(score: VocalScore, phrase: VocalPhrase, transposition: Int) {
        stop()
        feedback = nil
        resetReadings()
        let events = Self.events(score: score, phrase: phrase, transposition: transposition)
        let renderTask = Task.detached(priority: .userInitiated) {
            ToneSequenceRenderer.render(events: events)
        }
        phraseRenderTask = renderTask
        previewTask = Task { [weak self] in
            guard let self else { return }
            let samples = await renderTask.value
            guard !Task.isCancelled else { return }
            player.playPhrase(samples, duringCapture: false)
            try? await Task.sleep(for: .seconds(max(0.1, phrase.end - phrase.start + ToneSequenceRenderer.releaseDuration)))
            guard !Task.isCancelled else { return }
            player.stopPhrase()
            previewTask = nil
            phraseRenderTask = nil
        }
    }

    func stop() {
        attemptTask?.cancel()
        attemptTask = nil
        previewTask?.cancel()
        previewTask = nil
        phraseRenderTask?.cancel()
        phraseRenderTask = nil
        awaitingMicrophone = false
        phase = .idle
        feedback = nil
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
            let samples = await phraseRenderTask?.value ?? []
            guard !Task.isCancelled else { return }
            resetReadings()
            recordingStart = ProcessInfo.processInfo.systemUptime
            phase = .recording
            player.playPhrase(samples, duringCapture: true)
            try? await Task.sleep(for: .seconds(max(0.2, phrase.end - phrase.start + 0.15)))
            guard !Task.isCancelled else { return }
            finish()
        }
    }

    private func finish() {
        phase = .finished
        microphone.stop()
        player.stopPhrase()
        if let score, let phrase {
            feedback = PhraseScoring.evaluate(score: score, phrase: phrase,
                                              readings: scoringReadings, transposition: transposition)
        }
        attemptTask = nil
        phraseRenderTask = nil
    }

    private func resetReadings() {
        scoringReadings = []
        readings = []
        displayLimiter.reset()
        currentHz = nil
    }

    private static func events(score: VocalScore, phrase: VocalPhrase, transposition: Int) -> [ToneSequenceEvent] {
        let events = phrase.noteRange.compactMap { index in
            guard score.notes.indices.contains(index) else { return nil }
            let note = score.notes[index]
            return ToneSequenceEvent(midi: note.midi,
                                     onset: max(0, note.onset - phrase.start), duration: note.duration)
        }
        return ToneSequenceRenderer.transposed(events, by: transposition)
    }
}
