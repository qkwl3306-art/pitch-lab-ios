import XCTest
@testable import PitchLab

final class KeyRecommendationTests: XCTestCase {
    func testRangeBoundariesAreInclusive() {
        let advice = KeyRecommendation.recommend(notes: [60, 72], range: VocalRange(low: 60, high: 72))

        XCTAssertEqual(advice.semitones, 0)
        XCTAssertEqual(advice.coveredNoteCount, 2)
        XCTAssertEqual(advice.outOfRangeNoteCount, 0)
        XCTAssertEqual(advice.coverage, 1)
        XCTAssertEqual(advice.originalCoverage, 1)
        XCTAssertEqual(advice.lowestNote, 60)
        XCTAssertEqual(advice.highestNote, 72)
    }

    func testCoverageTakesPriorityOverClearanceAndShiftSize() {
        let advice = KeyRecommendation.recommend(notes: [60, 67, 72], range: VocalRange(low: 61, high: 73))

        XCTAssertEqual(advice.semitones, 1)
        XCTAssertEqual(advice.coveredNoteCount, 3)
        XCTAssertEqual(advice.originalCoveredNoteCount, 2)
        XCTAssertEqual(advice.originalCoverage, 2.0 / 3.0, accuracy: 0.000_001)
    }

    func testClearanceWinsAmongFullyCoveredKeys() {
        let advice = KeyRecommendation.recommend(notes: [62, 70], range: VocalRange(low: 60, high: 76))

        XCTAssertEqual(advice.semitones, 2)
        XCTAssertEqual(advice.clearance, 4)
    }

    func testClearanceCanFavorAShiftOverOriginalKey() {
        let advice = KeyRecommendation.recommend(notes: [62, 70], range: VocalRange(low: 58, high: 74))

        XCTAssertEqual(advice.semitones, 0)
        XCTAssertEqual(advice.clearance, 4)
    }

    func testSmallerShiftWinsWhenCoverageAndClearanceTie() {
        let advice = KeyRecommendation.recommend(notes: [48, 60, 72], range: VocalRange(low: 60, high: 72))

        XCTAssertEqual(advice.semitones, 0)
        XCTAssertEqual(advice.coveredNoteCount, 2)
        XCTAssertEqual(advice.outOfRangeNoteCount, 1)
        XCTAssertEqual(advice.coverage, 2.0 / 3.0, accuracy: 0.000_001)
    }

    func testEmptyMelodyHasNoLimitsOrCoverage() {
        let advice = KeyRecommendation.recommend(notes: [], range: VocalRange(low: 60, high: 72))

        XCTAssertEqual(advice.semitones, 0)
        XCTAssertEqual(advice.coverage, 0)
        XCTAssertNil(advice.lowestNote)
        XCTAssertNil(advice.highestNote)
    }

    func testVocalRangeCanBeSavedLocallyAsJSON() throws {
        let range = VocalRange(low: 48, high: 84)
        let restored = try JSONDecoder().decode(VocalRange.self, from: JSONEncoder().encode(range))

        XCTAssertEqual(restored, range)
    }
}
