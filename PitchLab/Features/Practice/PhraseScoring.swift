import Foundation

struct TimedPitchReading: Equatable {
    let time: Double
    let frequency: Double?
}

enum NoteFeedbackStatus: String, Codable, Equatable {
    case passed
    case high
    case low
    case missed
}

struct NoteFeedback: Equatable {
    let noteIndex: Int
    let targetMIDI: Int
    let status: NoteFeedbackStatus
    let cents: Double?
}

struct PhraseFeedback: Equatable {
    let notes: [NoteFeedback]
    var passed: Bool { !notes.isEmpty && notes.allSatisfy { $0.status == .passed } }
}

enum PhraseScoring {
    static func evaluate(score: VocalScore, phrase: VocalPhrase,
                         readings: [TimedPitchReading], transposition: Int) -> PhraseFeedback {
        guard phrase.noteRange.lowerBound >= 0,
              phrase.noteRange.upperBound <= score.notes.count else {
            return PhraseFeedback(notes: [])
        }
        let feedback = phrase.noteRange.map { index -> NoteFeedback in
            let note = score.notes[index]
            let target = note.midi + transposition
            let trim = min(0.08, note.duration * 0.15)
            let start = note.onset + trim
            let end = note.onset + note.duration - trim
            let expectedFrames = max(1, Int((end - start) / 0.1))
            let cents = readings.compactMap { sample -> Double? in
                guard sample.time >= start, sample.time <= end,
                      let frequency = sample.frequency, frequency.isFinite, frequency > 0 else { return nil }
                let deviation = NoteMath.cents(frequency: frequency, midi: target)
                return deviation.isFinite ? deviation : nil
            }
            guard Double(cents.count) / Double(expectedFrames) >= 0.4,
                  !cents.isEmpty else {
                return NoteFeedback(noteIndex: index, targetMIDI: target, status: .missed, cents: nil)
            }
            let ordered = cents.sorted()
            let median = ordered[ordered.count / 2]
            let accurate = cents.filter { abs($0) <= 50 }.count
            let status: NoteFeedbackStatus
            if Double(accurate) / Double(cents.count) >= 0.6 {
                status = .passed
            } else {
                status = median >= 0 ? .high : .low
            }
            return NoteFeedback(noteIndex: index, targetMIDI: target, status: status, cents: median)
        }
        return PhraseFeedback(notes: feedback)
    }
}
