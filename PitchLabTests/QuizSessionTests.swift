import XCTest
@testable import PitchLab

final class QuizSessionTests: XCTestCase {
    func testTenAnswersFinishRoundAndScoreCorrectly() {
        var quiz = QuizSession(notes: [60, 61, 62, 63, 64, 65, 66, 67, 68, 69])
        XCTAssertFalse(quiz.isFinished)
        for note in quiz.notes.prefix(9) {
            quiz.answer(pitchClass: note % 12)
        }
        XCTAssertFalse(quiz.isFinished)
        quiz.answer(pitchClass: 0)
        XCTAssertTrue(quiz.isFinished)
        XCTAssertEqual(quiz.score, 9)
        XCTAssertEqual(quiz.answers.count, 10)
    }

    func testExtraAnswersAreIgnored() {
        var quiz = QuizSession(notes: [60])
        quiz.answer(pitchClass: 0)
        quiz.answer(pitchClass: 1)
        XCTAssertEqual(quiz.answers, [0])
    }
}
