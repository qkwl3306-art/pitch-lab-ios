import Combine
import Foundation

@MainActor
final class PracticeViewModel: ObservableObject {
    @Published private(set) var pitchHz: Double?
    @Published private(set) var status: MicrophonePitchService.Status = .idle
    @Published private(set) var history: [PitchReading] = []
    @Published private(set) var session: PracticeSession?

    private let microphone = MicrophonePitchService()
    private let player = TonePlayer()
    private var subscriptions = Set<AnyCancellable>()
    private var accurateFrames = 0
    private var playbackTask: Task<Void, Never>?

    var currentName: String { pitchHz.flatMap(NoteMath.nearestMIDINote(frequency:)).map(NoteMath.name(midi:)) ?? "—" }
    var targetName: String { session?.currentMIDI.map(NoteMath.name(midi:)) ?? "—" }
    var cents: Double? {
        guard let pitchHz, let target = session?.currentMIDI else { return nil }
        return NoteMath.cents(frequency: pitchHz, midi: target)
    }

    init() {
        microphone.$pitchHz.sink { [weak self] hz in self?.accept(hz) }.store(in: &subscriptions)
        microphone.$status.sink { [weak self] status in self?.status = status }.store(in: &subscriptions)
    }

    func select(_ score: StoredScore) {
        session = score.notes.isEmpty ? nil : PracticeSession(notes: score.notes)
        accurateFrames = 0
        history = []
    }

    func start() { microphone.start() }
    func stop() {
        microphone.stop()
        playbackTask?.cancel()
        player.stopAll()
    }

    func next() {
        session?.next()
        accurateFrames = 0
    }

    func previous() {
        session?.previous()
        accurateFrames = 0
    }

    func playTarget() {
        guard let note = session?.currentMIDI else { return }
        playbackTask?.cancel()
        player.stopAll()
        player.noteOn(midi: note)
        playbackTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            self?.player.noteOff(midi: note)
        }
    }

    private func accept(_ hz: Double?) {
        pitchHz = hz
        let now = Date()
        let midi = hz.map { 69 + 12 * log2($0 / 440) }
        history.append(PitchReading(time: now, midi: midi))
        history.removeAll { now.timeIntervalSince($0.time) > 10 }
        guard var session, let target = session.currentMIDI else { return }
        if PracticeScoring.isAccurate(frequency: hz, targetMIDI: target) {
            accurateFrames += 1
            if accurateFrames >= 3 {
                session.accept(frequency: hz)
                self.session = session
            }
        } else {
            accurateFrames = 0
        }
    }
}
