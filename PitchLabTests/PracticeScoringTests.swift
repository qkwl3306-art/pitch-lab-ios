import XCTest
@testable import PitchLab

final class PracticeScoringTests: XCTestCase {
    func testThirtyCentBoundary() {
        let target = NoteMath.frequency(midi: 69)
        XCTAssertTrue(PracticeScoring.isAccurate(frequency: target, targetMIDI: 69))
        XCTAssertTrue(PracticeScoring.isAccurate(frequency: target * pow(2, 29.9 / 1200), targetMIDI: 69))
        XCTAssertFalse(PracticeScoring.isAccurate(frequency: target * pow(2, 31 / 1200), targetMIDI: 69))
    }

    func testMissingPitchIsNotAccurate() {
        XCTAssertFalse(PracticeScoring.isAccurate(frequency: nil, targetMIDI: 69))
    }
}
