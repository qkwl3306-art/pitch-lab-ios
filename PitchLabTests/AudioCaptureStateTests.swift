import XCTest
@testable import PitchLab

final class AudioCaptureStateTests: XCTestCase {
    func testStoppedPermissionRequestCannotStartCapture() {
        var intent = CaptureIntent()
        let request = intent.begin()
        intent.cancel()
        XCTAssertFalse(intent.isCurrent(request))
    }

    func testOnlyOneAnalysisRunsAtATime() {
        let gate = AudioAnalysisGate()
        XCTAssertTrue(gate.begin())
        XCTAssertFalse(gate.begin())
        gate.end()
        XCTAssertTrue(gate.begin())
    }
}
