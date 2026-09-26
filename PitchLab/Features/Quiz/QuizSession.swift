import Foundation

struct QuizSession {
    let notes: [Int]
    private(set) var answers: [Int] = []

    var isFinished: Bool { answers.count >= notes.count }
    var currentNote: Int? { isFinished ? nil : notes[answers.count] }
    var score: Int {
        zip(notes, answers).filter { note, answer in note % 12 == answer }.count
    }

    mutating func answer(pitchClass: Int) {
        guard !isFinished, (0...11).contains(pitchClass) else { return }
        answers.append(pitchClass)
    }

    static func randomRound() -> QuizSession {
        QuizSession(notes: (0..<10).map { _ in Int.random(in: 60...83) })
    }
}
