import Foundation

struct KeyAdvice: Equatable {
    let semitones: Int
    let coveredNoteCount: Int
    let outOfRangeNoteCount: Int
    let originalCoveredNoteCount: Int
    let totalNoteCount: Int
    let lowestNote: Int?
    let highestNote: Int?
    /// The smaller distance from the shifted melody's extremes to the singer's limits.
    /// Negative values indicate that at least one extreme lies outside the range.
    let clearance: Int

    var coverage: Double {
        totalNoteCount == 0 ? 0 : Double(coveredNoteCount) / Double(totalNoteCount)
    }

    var originalCoverage: Double {
        totalNoteCount == 0 ? 0 : Double(originalCoveredNoteCount) / Double(totalNoteCount)
    }
}

enum KeyRecommendation {
    static func recommend(notes: [Int], range: VocalRange) -> KeyAdvice {
        guard let originalLow = notes.min(), let originalHigh = notes.max() else {
            return KeyAdvice(
                semitones: 0,
                coveredNoteCount: 0,
                outOfRangeNoteCount: 0,
                originalCoveredNoteCount: 0,
                totalNoteCount: 0,
                lowestNote: nil,
                highestNote: nil,
                clearance: 0
            )
        }

        let originalCoveredCount = notes.filter { range.low...range.high ~= $0 }.count
        var best: KeyAdvice?

        for semitones in -12...12 {
            let low = originalLow + semitones
            let high = originalHigh + semitones
            let coveredCount = notes.filter { range.low...range.high ~= ($0 + semitones) }.count
            let candidate = KeyAdvice(
                semitones: semitones,
                coveredNoteCount: coveredCount,
                outOfRangeNoteCount: notes.count - coveredCount,
                originalCoveredNoteCount: originalCoveredCount,
                totalNoteCount: notes.count,
                lowestNote: low,
                highestNote: high,
                clearance: min(low - range.low, range.high - high)
            )

            if let current = best {
                if candidate.coveredNoteCount > current.coveredNoteCount
                    || (candidate.coveredNoteCount == current.coveredNoteCount
                        && candidate.clearance > current.clearance)
                    || (candidate.coveredNoteCount == current.coveredNoteCount
                        && candidate.clearance == current.clearance
                        && abs(candidate.semitones) < abs(current.semitones)) {
                    best = candidate
                }
            } else {
                best = candidate
            }
        }

        return best!
    }
}
