import Foundation

enum NoteMath {
    static let pitchClasses = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]

    static func frequency(midi: Int) -> Double {
        440 * pow(2, Double(midi - 69) / 12)
    }

    static func nearestMIDINote(frequency: Double) -> Int? {
        guard frequency.isFinite, frequency > 0 else { return nil }
        let value = 69 + 12 * log2(frequency / 440)
        guard value.isFinite, value >= 0, value <= 127 else { return nil }
        return Int(value.rounded())
    }

    static func cents(frequency: Double, midi: Int) -> Double {
        1200 * log2(frequency / self.frequency(midi: midi))
    }

    static func name(midi: Int) -> String {
        let pitchClass = ((midi % 12) + 12) % 12
        let octave = midi / 12 - 1
        return "\(pitchClasses[pitchClass])\(octave)"
    }
}
