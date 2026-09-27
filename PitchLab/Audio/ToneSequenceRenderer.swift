import Foundation

struct ToneSequenceEvent: Equatable, Sendable {
    let midi: Int
    let onset: Double
    let duration: Double
}

enum ToneSequenceRenderer {
    static let releaseDuration = 0.12

    static func transposed(_ events: [ToneSequenceEvent], by semitones: Int) -> [ToneSequenceEvent] {
        events.map { ToneSequenceEvent(midi: $0.midi + semitones, onset: $0.onset, duration: $0.duration) }
    }

    static func render(events: [ToneSequenceEvent], sampleRate: Double = 44_100) -> [Float] {
        guard sampleRate.isFinite, sampleRate > 0 else { return [] }
        let validEvents = events.filter {
            (0...127).contains($0.midi) && $0.onset.isFinite && $0.onset >= 0
                && $0.duration.isFinite && $0.duration > 0
        }
        guard let end = validEvents.map({ $0.onset + $0.duration + releaseDuration }).max(),
              end.isFinite, end <= 120 else { return [] }

        let frameCount = Int((end * sampleRate).rounded(.up))
        guard frameCount > 0 else { return [] }
        var samples = Array(repeating: Float.zero, count: frameCount)

        for event in validEvents {
            let startFrame = Int((event.onset * sampleRate).rounded())
            let noteEnd = event.onset + event.duration
            let endFrame = min(frameCount, Int(((noteEnd + releaseDuration) * sampleRate).rounded(.up)))
            let frequency = 440 * pow(2, Double(event.midi - 69) / 12)
            for frame in startFrame..<endFrame {
                let time = Double(frame) / sampleRate - event.onset
                let release = time <= event.duration ? 1 : max(0, 1 - (time - event.duration) / releaseDuration)
                let attack = min(1, time / 0.01)
                let fundamental = sin(2 * .pi * frequency * time) * exp(-time * 0.45)
                let second = sin(4 * .pi * frequency * time) * 0.18 * exp(-time * 2.2)
                let third = sin(6 * .pi * frequency * time) * 0.055 * exp(-time * 4.5)
                samples[frame] += Float((fundamental + second + third) * 0.82 * attack * release)
            }
        }

        let peak = samples.reduce(Float.zero) { max($0, abs($1)) }
        if peak > 0.95 {
            let scale = 0.95 / peak
            samples = samples.map { $0 * scale }
        }
        return samples
    }
}
