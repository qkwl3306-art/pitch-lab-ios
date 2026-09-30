import XCTest
@testable import PitchLab

final class PhrasePracticeViewModelTests: XCTestCase {
    @MainActor
    func testStopClearsPreviousPhrasePresentation() {
        let model = PhrasePracticeViewModel()
        model.begin(score: score, phrase: phrase, transposition: 0, mode: .wholePhrase)
        model.skipCurrent()
        model.stop()
        XCTAssertNil(model.targetNoteIndex)
        XCTAssertNil(model.targetName)
        XCTAssertTrue(model.skippedNoteIndices.isEmpty)
        XCTAssertTrue(model.readings.isEmpty)
    }

    @MainActor
    func testSkippedNotesWithoutPitchEvidenceArePendingRetry() {
        let model = PhrasePracticeViewModel()
        model.begin(score: score, phrase: phrase, transposition: 0, mode: .wholePhrase)
        model.skipCurrent()
        model.skipCurrent()
        XCTAssertEqual(model.feedback?.notes.map(\.status), [.missed, .missed])
        model.stop()
    }

    private var score: VocalScore {
        VocalScore(notes: [60, 62].enumerated().map {
            VocalNote(onset: Double($0.offset), duration: 1, midi: $0.element, lyric: nil)
        }, title: "Test")
    }
    private var phrase: VocalPhrase {
        VocalPhrase(id: 0, noteRange: 0..<2, start: 0, end: 2, text: "Test")
    }
}
