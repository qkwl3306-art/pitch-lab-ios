import XCTest
@testable import PitchLab

final class PracticeAccessTests: XCTestCase {
    func testTrialExpiresExactlyAtSevenDays() {
        let start = Date(timeIntervalSince1970: 1_000)
        let end = start.addingTimeInterval(604_800)
        XCTAssertEqual(PracticeAccess.evaluate(trialStarted: start, purchased: false, now: end.addingTimeInterval(-1)), .trial(until: end))
        XCTAssertEqual(PracticeAccess.evaluate(trialStarted: start, purchased: false, now: end), .locked)
    }

    func testPurchaseOverridesExpiredTrial() {
        XCTAssertEqual(PracticeAccess.evaluate(trialStarted: .distantPast, purchased: true, now: Date()), .unlocked)
    }

    func testMissingOrFutureTransactionDoesNotGrantAccess() {
        XCTAssertEqual(PracticeAccess.evaluate(trialStarted: nil, purchased: false, now: Date()), .locked)
        XCTAssertEqual(PracticeAccess.evaluate(trialStarted: .distantFuture, purchased: false, now: Date()), .locked)
    }
}
