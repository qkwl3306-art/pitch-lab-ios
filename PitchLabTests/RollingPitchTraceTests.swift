import XCTest
@testable import PitchLab

final class RollingPitchTraceTests: XCTestCase {
    func testLongPracticeKeepsRecentSamplesVisible() {
        let trace = RollingPitchTrace(latestTime: 600)
        XCTAssertNil(trace.position(at: 590))
        XCTAssertEqual(trace.position(at: 592), 0)
        XCTAssertEqual(trace.position(at: 596), 0.5)
        XCTAssertEqual(trace.position(at: 600), 1)
    }

    func testNewAttemptStartsInsideGraph() {
        let trace = RollingPitchTrace(latestTime: 0.2)
        XCTAssertEqual(trace.position(at: 0.2) ?? -1, 0.025, accuracy: 0.0001)
    }

    func testFractionalPitchPreservesIntonationDeviation() {
        let frequency = NoteMath.frequency(midi: 60) * pow(2, 30.0 / 1200)
        XCTAssertEqual(RollingPitchTrace.midi(frequency: frequency) ?? 0, 60.3, accuracy: 0.0001)
        XCTAssertNil(RollingPitchTrace.midi(frequency: .nan))
        XCTAssertNil(RollingPitchTrace.midi(frequency: 0))
    }
}
