import XCTest
@testable import PitchLab

final class VocalRangeSamplingTests: XCTestCase {
    func testStableSustainedNoteUsesMedian() {
        let pitches = [220.0, 219.2, 221.0, 220.5, 330.0]
        XCTAssertEqual(VocalRangeSampling.stableMIDI(frequencies: pitches), 57)
    }

    func testShortOrWideSamplesAreRejected() {
        XCTAssertNil(VocalRangeSampling.stableMIDI(frequencies: [220]))
        XCTAssertNil(VocalRangeSampling.stableMIDI(frequencies: [220, 260, 330, 440]))
    }
}
