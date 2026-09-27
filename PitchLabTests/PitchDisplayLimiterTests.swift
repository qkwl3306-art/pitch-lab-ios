import XCTest
@testable import PitchLab

final class PitchDisplayLimiterTests: XCTestCase {
    func testLimitsPublishedPitchUpdatesToFivePerSecond() {
        var limiter = PitchDisplayLimiter()

        XCTAssertTrue(limiter.shouldPublish(at: 1.0))
        XCTAssertFalse(limiter.shouldPublish(at: 1.1))
        XCTAssertTrue(limiter.shouldPublish(at: 1.2))
        XCTAssertFalse(limiter.shouldPublish(at: 1.39))
        XCTAssertTrue(limiter.shouldPublish(at: 1.4))
    }

    func testLongGapAllowsImmediateNextDisplayUpdate() {
        var limiter = PitchDisplayLimiter()

        XCTAssertTrue(limiter.shouldPublish(at: 3.0))
        XCTAssertTrue(limiter.shouldPublish(at: 4.0))
    }
}
