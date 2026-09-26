import Combine
import Foundation

struct PitchReading: Identifiable {
    let id = UUID()
    let time: Date
    let midi: Double?
}

@MainActor
final class PitchViewModel: ObservableObject {
    @Published private(set) var pitchHz: Double?
    @Published private(set) var status: MicrophonePitchService.Status = .idle
    @Published private(set) var history: [PitchReading] = []

    private let microphone = MicrophonePitchService()
    private var subscriptions = Set<AnyCancellable>()

    var midi: Int? { pitchHz.flatMap(NoteMath.nearestMIDINote(frequency:)) }
    var noteName: String { midi.map(NoteMath.name(midi:)) ?? "—" }
    var cents: Double? {
        guard let pitchHz, let midi else { return nil }
        return NoteMath.cents(frequency: pitchHz, midi: midi)
    }

    init() {
        microphone.$pitchHz.sink { [weak self] hz in self?.accept(hz) }.store(in: &subscriptions)
        microphone.$status.sink { [weak self] value in self?.status = value }.store(in: &subscriptions)
    }

    func start() { microphone.start() }
    func stop() { microphone.stop() }

    private func accept(_ hz: Double?) {
        pitchHz = hz
        let now = Date()
        let continuousNote = hz.map { 69 + 12 * log2($0 / 440) }
        history.append(PitchReading(time: now, midi: continuousNote))
        history.removeAll { now.timeIntervalSince($0.time) > 10 }
    }
}
