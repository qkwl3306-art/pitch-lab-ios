import XCTest
@testable import PitchLab

final class SelfPacedPracticeSessionTests: XCTestCase {
    func testStartsAtFirstNoteInEachMode() {
        for mode in SelfPacedPracticeMode.allCases {
            let session = SelfPacedPracticeSession(noteRange: 4..<7, mode: mode)

            XCTAssertEqual(session.currentNoteIndex, 4, "mode: \(mode)")
            XCTAssertFalse(session.isComplete, "mode: \(mode)")
        }
    }

    func testNoteByNoteRequiresStablePitchAndWaitsForManualAdvance() {
        var session = SelfPacedPracticeSession(noteRange: 4..<6, mode: .noteByNote)
        let frequency = NoteMath.frequency(midi: 60)

        XCTAssertFalse(session.observe(frequency: frequency, targetMIDI: 60, at: 1.0).didPass)
        XCTAssertFalse(session.observe(frequency: frequency, targetMIDI: 60, at: 1.2).didPass)
        XCTAssertTrue(session.observe(frequency: frequency, targetMIDI: 60, at: 1.3).didPass)
        XCTAssertEqual(session.currentNoteIndex, 4)
        XCTAssertEqual(session.passedNoteIndices, [4])

        session.advance()
        XCTAssertEqual(session.currentNoteIndex, 5)
    }

    func testWrongPitchAndShortSilenceKeepTheCurrentTargetActive() {
        var session = SelfPacedPracticeSession(noteRange: 2..<4, mode: .wholePhrase)
        let wrongFrequency = NoteMath.frequency(midi: 62)

        let wrong = session.observe(frequency: wrongFrequency, targetMIDI: 60, at: 1.0)
        let silence = session.observe(frequency: nil, targetMIDI: 60, at: 2.5)

        XCTAssertGreaterThan(wrong.cents ?? 0, 50)
        XCTAssertFalse(wrong.didPass)
        XCTAssertFalse(silence.didPass)
        XCTAssertEqual(session.currentNoteIndex, 2)
        XCTAssertTrue(session.skippedNoteIndices.isEmpty)
    }

    func testAdvancingAnInaccurateNoteRecordsItForRetry() {
        var session = SelfPacedPracticeSession(noteRange: 3..<5, mode: .noteByNote)

        session.advance()

        XCTAssertEqual(session.skippedNoteIndices, [3])
        XCTAssertEqual(session.unresolvedNoteIndices, [3, 4])
        XCTAssertEqual(session.currentNoteIndex, 4)
    }

    func testProgressiveModeExpandsOnlyAfterSingingEachPrefixAccurately() {
        var session = SelfPacedPracticeSession(noteRange: 0..<3, mode: .progressive)

        XCTAssertEqual(session.progressiveEndIndex, 0)
        XCTAssertTrue(confirm(&session, midi: 60, at: 1.0).didExpandStage)
        XCTAssertEqual(session.currentNoteIndex, 0)
        XCTAssertEqual(session.progressiveEndIndex, 1)

        _ = session.observe(frequency: nil, targetMIDI: 60, at: 1.5)
        XCTAssertFalse(confirm(&session, midi: 60, at: 2.0).didExpandStage)
        XCTAssertTrue(confirm(&session, midi: 62, at: 2.5).didExpandStage)
        XCTAssertEqual(session.currentNoteIndex, 0)
        XCTAssertEqual(session.progressiveEndIndex, 2)
    }

    func testWholePhraseModeAdvancesAutomaticallyAfterStableAccuratePitch() {
        var session = SelfPacedPracticeSession(noteRange: 0..<2, mode: .wholePhrase)

        let update = confirm(&session, midi: 60, at: 1.0)

        XCTAssertTrue(update.didPass)
        XCTAssertEqual(session.currentNoteIndex, 1)
        XCTAssertEqual(session.passedNoteIndices, [0])
    }

    func testConsecutiveRepeatedNotesNeedAPitchBreakBeforeAutoAdvance() {
        var session = SelfPacedPracticeSession(noteRange: 0..<2, mode: .wholePhrase)
        _ = confirm(&session, midi: 60, at: 1.0)

        XCTAssertFalse(session.observe(frequency: NoteMath.frequency(midi: 60), targetMIDI: 60, at: 2.0).didPass)
        XCTAssertFalse(session.observe(frequency: NoteMath.frequency(midi: 60), targetMIDI: 60, at: 2.3).didPass)
        XCTAssertEqual(session.currentNoteIndex, 1)

        _ = session.observe(frequency: nil, targetMIDI: 60, at: 2.4)
        XCTAssertFalse(session.observe(frequency: NoteMath.frequency(midi: 60), targetMIDI: 60, at: 2.5).didPass)
        XCTAssertTrue(session.observe(frequency: NoteMath.frequency(midi: 60), targetMIDI: 60, at: 2.8).didPass)
        XCTAssertNil(session.currentNoteIndex)
    }

    func testCompletionSummaryAllowsRetryAndRestartWithoutLosingResultsUntilRequested() {
        var session = SelfPacedPracticeSession(noteRange: 0..<1, mode: .wholePhrase)
        _ = confirm(&session, midi: 60, at: 1.0)
        XCTAssertTrue(session.isComplete)

        session.retry(noteIndex: 0)
        XCTAssertFalse(session.isComplete)
        XCTAssertEqual(session.currentNoteIndex, 0)

        session.restart()
        XCTAssertEqual(session.currentNoteIndex, 0)
        XCTAssertTrue(session.passedNoteIndices.isEmpty)
        XCTAssertTrue(session.skippedNoteIndices.isEmpty)
    }

    func testFinalFeedbackShowsMissedOrInaccurateNoteWithoutTreatingSilenceAsMiss() {
        var session = SelfPacedPracticeSession(noteRange: 0..<2, mode: .wholePhrase)
        _ = confirm(&session, midi: 60, at: 1.0)
        _ = session.observe(frequency: nil, targetMIDI: 62, at: 2.0)
        session.skipCurrent()

        XCTAssertTrue(session.isComplete)
        XCTAssertEqual(session.passedNoteIndices, [0])
        XCTAssertEqual(session.skippedNoteIndices, [1])
        XCTAssertEqual(session.unresolvedNoteIndices, [1])
    }

    func testNoteByNoteCompletesAfterAllNotesAreConfirmedWithoutStoppingSessionState() {
        var session = SelfPacedPracticeSession(noteRange: 0..<2, mode: .noteByNote)
        _ = confirm(&session, midi: 60, at: 1.0)
        XCTAssertFalse(session.isComplete)
        session.advance()
        _ = confirm(&session, midi: 62, at: 2.0)

        XCTAssertTrue(session.isComplete)
        XCTAssertEqual(session.passedNoteIndices, [0, 1])
    }

    func testManualAdvanceAfterCorrectNoteDoesNotMarkThatNoteSkipped() {
        var session = SelfPacedPracticeSession(noteRange: 0..<2, mode: .noteByNote)
        _ = confirm(&session, midi: 60, at: 1.0)
        session.advance()

        XCTAssertEqual(session.passedNoteIndices, [0])
        XCTAssertTrue(session.skippedNoteIndices.isEmpty)
        XCTAssertEqual(session.currentNoteIndex, 1)
    }

    func testRetryFromCompletedPhraseReopensRequestedNote() {
        var session = SelfPacedPracticeSession(noteRange: 0..<1, mode: .wholePhrase)
        _ = confirm(&session, midi: 60, at: 1.0)
        XCTAssertTrue(session.isComplete)
        session.retry(noteIndex: 0)

        XCTAssertEqual(session.currentNoteIndex, 0)
        XCTAssertTrue(session.passedNoteIndices.isEmpty)
        XCTAssertFalse(session.isComplete)
    }

    @discardableResult
    private func confirm(_ session: inout SelfPacedPracticeSession, midi: Int, at start: TimeInterval) -> SelfPacedPitchUpdate {
        let frequency = NoteMath.frequency(midi: midi)
        _ = session.observe(frequency: frequency, targetMIDI: midi, at: start)
        return session.observe(frequency: frequency, targetMIDI: midi, at: start + 0.3)
    }
}
