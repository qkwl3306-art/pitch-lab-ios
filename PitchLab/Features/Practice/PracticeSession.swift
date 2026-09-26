import Foundation

enum PracticeScoring {
    static func isAccurate(frequency: Double?, targetMIDI: Int) -> Bool {
        guard let frequency, frequency.isFinite, frequency > 0 else { return false }
        return abs(NoteMath.cents(frequency: frequency, midi: targetMIDI)) <= 30
    }
}

struct PracticeSession {
    let notes: [Int]
    private(set) var index = 0
    private(set) var currentPassed = false
    private(set) var transposition = 0
    private(set) var passedIndices: Set<Int> = []

    var passedCount: Int { passedIndices.count }

    var currentMIDI: Int? { notes.indices.contains(index) ? notes[index] + transposition : nil }

    mutating func setTransposition(_ semitones: Int) {
        let limited = max(-12, min(12, semitones))
        guard limited != transposition else { return }
        transposition = limited
        currentPassed = false
        passedIndices.removeAll()
    }

    mutating func accept(frequency: Double?) {
        guard let currentMIDI else { return }
        if PracticeScoring.isAccurate(frequency: frequency, targetMIDI: currentMIDI) {
            currentPassed = true
            passedIndices.insert(index)
        }
    }

    mutating func next() {
        guard index + 1 < notes.count else { return }
        index += 1
        currentPassed = passedIndices.contains(index)
    }

    mutating func previous() {
        guard index > 0 else { return }
        index -= 1
        currentPassed = passedIndices.contains(index)
    }
}
