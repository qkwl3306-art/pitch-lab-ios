import Foundation

enum VocalRangeSampling {
    static func stableMIDI(frequencies: [Double]) -> Int? {
        let pitches = frequencies.filter { $0.isFinite && $0 > 0 }
            .map { 69 + 12 * log2($0 / 440) }
            .sorted()
        guard pitches.count >= 4 else { return nil }
        let median = pitches[pitches.count / 2]
        let near = pitches.filter { abs($0 - median) <= 0.6 }
        guard Double(near.count) / Double(pitches.count) >= 0.75 else { return nil }
        return Int(median.rounded())
    }
}
