import AVFoundation
import Combine
import Foundation

@MainActor
final class PhrasePracticeViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case starting
        case listening
        case finished
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var microphoneStatus: MicrophonePitchService.Status = .idle
    @Published private(set) var mode: SelfPacedPracticeMode = .noteByNote
    @Published private(set) var currentHz: Double?
    @Published private(set) var targetCents: Double?
    @Published private(set) var readings: [TimedPitchReading] = []
    @Published private(set) var feedback: PhraseFeedback?
    @Published private(set) var targetNoteIndex: Int?
    @Published private(set) var passedNoteIndices: Set<Int> = []
    @Published private(set) var skippedNoteIndices: Set<Int> = []
    @Published private(set) var progressiveEndIndex: Int?

    private let microphone = MicrophonePitchService()
    private let player = TonePlayer()
    private var displayLimiter = PitchDisplayLimiter()
    private var subscriptions = Set<AnyCancellable>()
    private var previewTask: Task<Void, Never>?
    private var phraseRenderTask: Task<[Float], Never>?
    private var score: VocalScore?
    private var phrase: VocalPhrase?
    private var transposition = 0
    private var session: SelfPacedPracticeSession?
    private var lastRawFrequency: Double?
    private var practiceStartTime: TimeInterval = 0

    var currentName: String {
        currentHz.flatMap(NoteMath.nearestMIDINote(frequency:)).map(NoteMath.name(midi:)) ?? "—"
    }

    var targetName: String? {
        guard let index = targetNoteIndex, let score, score.notes.indices.contains(index) else { return nil }
        return NoteMath.name(midi: score.notes[index].midi + transposition)
    }

    var unresolvedNoteIndices: Set<Int> { session?.unresolvedNoteIndices ?? [] }
    var isComplete: Bool { session?.isComplete ?? false }

    init() {
        microphone.$status.sink { [weak self] status in
            guard let self else { return }
            self.microphoneStatus = status
            if status == .listening, self.phase == .starting { self.phase = .listening }
        }.store(in: &subscriptions)
        microphone.$pitchHz.sink { [weak self] hz in self?.receivePitch(hz) }.store(in: &subscriptions)
    }

    func begin(score: VocalScore, phrase: VocalPhrase, transposition: Int,
               mode: SelfPacedPracticeMode) {
        stop()
        self.score = score
        self.phrase = phrase
        self.transposition = transposition
        self.mode = mode
        session = SelfPacedPracticeSession(noteRange: phrase.noteRange, mode: mode)
        targetNoteIndex = session?.currentNoteIndex
        progressiveEndIndex = session?.progressiveEndIndex
        passedNoteIndices = []
        skippedNoteIndices = []
        feedback = nil
        targetCents = nil
        lastRawFrequency = nil
        practiceStartTime = ProcessInfo.processInfo.systemUptime
        resetReadings()
        phase = .starting
        microphone.start(mode: .default)
        if microphone.status == .listening { phase = .listening }
    }

    func advance() {
        session?.advance()
        refreshSessionState()
    }

    func skipCurrent() {
        session?.skipCurrent()
        refreshSessionState()
    }

    func retryCurrent() {
        guard let targetNoteIndex else { return }
        retry(noteIndex: targetNoteIndex)
    }

    func retry(noteIndex: Int) {
        guard var session else { return }
        session.retry(noteIndex: noteIndex)
        self.session = session
        feedback = nil
        targetCents = nil
        phase = microphone.status == .listening ? .listening : .starting
        if microphone.status != .listening { microphone.start(mode: .default) }
        refreshSessionState()
    }

    func restart() {
        guard session != nil else { return }
        session?.restart()
        passedNoteIndices = []
        skippedNoteIndices = []
        feedback = nil
        targetCents = nil
        readings = []
        lastRawFrequency = nil
        phase = microphone.status == .listening ? .listening : .starting
        if microphone.status != .listening { microphone.start(mode: .default) }
        refreshSessionState()
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
        previewTask?.cancel()
        previewTask = nil
        phraseRenderTask?.cancel()
        phraseRenderTask = nil
        phase = .idle
        feedback = nil
        microphone.stop()
        player.stopAll()
    }

    private func receivePitch(_ frequency: Double?) {
        let now = ProcessInfo.processInfo.systemUptime
        if phase == .listening, let index = targetNoteIndex,
           let score, score.notes.indices.contains(index), var session {
            let midi = score.notes[index].midi + transposition
            let update = session.observe(frequency: frequency, targetMIDI: midi, at: now)
            self.session = session
            targetCents = update.cents
            let hasPitchBreak = frequency == nil || frequency.map { !isContinuousPitch($0, previous: lastRawFrequency) } == true
            if displayLimiter.shouldPublish(at: now) {
                currentHz = frequency
                if let phrase {
                    if readings.count == 256 { readings.removeFirst() }
                    let relativeTime = phrase.start + max(0, now - practiceStartTime)
                    if hasPitchBreak { readings.append(TimedPitchReading(time: relativeTime, frequency: nil)) }
                    if readings.count == 256 { readings.removeFirst() }
                    readings.append(TimedPitchReading(time: relativeTime, frequency: frequency))
                }
            }
            defer { lastRawFrequency = frequency }
            if update.didPass { handlePassedNote(index) }
            if update.didCompletePhrase { finishSession() }
            return
        }
        guard displayLimiter.shouldPublish(at: now) else { return }
        currentHz = frequency
    }

    private func isContinuousPitch(_ frequency: Double, previous: Double?) -> Bool {
        guard frequency.isFinite, frequency > 0, let previous, previous.isFinite, previous > 0 else { return false }
        return abs(NoteMath.cents(frequency: frequency, midi: NoteMath.nearestMIDINote(frequency: previous) ?? 0)) < 100
    }

    private func handlePassedNote(_ index: Int) {
        passedNoteIndices = session?.passedNoteIndices ?? passedNoteIndices
        skippedNoteIndices = session?.skippedNoteIndices ?? skippedNoteIndices
        progressiveEndIndex = session?.progressiveEndIndex
        targetNoteIndex = session?.currentNoteIndex
        if mode == .noteByNote || mode == .progressive { targetCents = 0 }
        _ = index
        if session?.isComplete == true { finishSession() }
    }

    private func refreshSessionState() {
        guard let session else { return }
        targetNoteIndex = session.currentNoteIndex
        progressiveEndIndex = session.progressiveEndIndex
        passedNoteIndices = session.passedNoteIndices
        skippedNoteIndices = session.skippedNoteIndices
        targetCents = nil
        if session.isComplete { finishSession() }
    }

    private func finishSession() {
        guard let phrase, let score else { return }
        phase = .finished
        passedNoteIndices = session?.passedNoteIndices ?? passedNoteIndices
        skippedNoteIndices = session?.skippedNoteIndices ?? skippedNoteIndices
        let activeIndex = targetNoteIndex
        let activeCents = targetCents
        targetNoteIndex = nil
        let notes = phrase.noteRange.map { index -> NoteFeedback in
            let target = score.notes[index].midi + transposition
            let status: NoteFeedbackStatus
            if passedNoteIndices.contains(index) { status = .passed }
            else if skippedNoteIndices.contains(index) { status = .low }
            else if let cents = activeCents, index == activeIndex {
                status = cents > 0 ? .high : .low
            } else { status = .missed }
            return NoteFeedback(noteIndex: index, targetMIDI: target, status: status,
                               cents: index == activeIndex ? activeCents : nil)
        }
        feedback = PhraseFeedback(notes: notes)
        // Keep the capture engine active so an unresolved note can be retried immediately.
        microphone.start(mode: .default)
        if microphone.status == .listening { phase = .finished }
    }

    private func resetReadings() {
        readings = []
        displayLimiter.reset()
        currentHz = nil
    }

    private static func events(score: VocalScore, phrase: VocalPhrase, transposition: Int) -> [ToneSequenceEvent] {
        let events = phrase.noteRange.compactMap { index -> ToneSequenceEvent? in
            guard score.notes.indices.contains(index) else { return nil }
            let note = score.notes[index]
            return ToneSequenceEvent(midi: note.midi,
                                     onset: max(0, note.onset - phrase.start), duration: note.duration)
        }
        return ToneSequenceRenderer.transposed(events, by: transposition)
    }
}
