import XCTest
@testable import PitchLab

final class PitchDetectorTests: XCTestCase {
    func testDetectsA4Sine() {
        let rate = 44_100.0
        let samples = (0..<4_096).map { index in
            Float(sin(2 * Double.pi * 440 * Double(index) / rate))
        }
        let detected = PitchDetector.detect(samples: samples, sampleRate: rate)
        XCTAssertNotNil(detected)
        XCTAssertEqual(detected ?? 0, 440, accuracy: 3)
    }

    func testSilenceHasNoPitch() {
        XCTAssertNil(PitchDetector.detect(samples: Array(repeating: 0, count: 4_096), sampleRate: 44_100))
    }
}
