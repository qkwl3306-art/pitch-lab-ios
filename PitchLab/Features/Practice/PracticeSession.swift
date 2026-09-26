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

    var currentMIDI: Int? { notes.indices.contains(index) ? notes[index] : nil }

    mutating func accept(frequency: Double?) {
        guard let currentMIDI else { return }
        if PracticeScoring.isAccurate(frequency: frequency, targetMIDI: currentMIDI) {
            currentPassed = true
        }
    }

    mutating func next() {
        guard index + 1 < notes.count else { return }
        index += 1
        currentPassed = false
    }

    mutating func previous() {
        guard index > 0 else { return }
        index -= 1
        currentPassed = false
    }
}
