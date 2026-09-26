import XCTest
@testable import PitchLab

final class NoteMathTests: XCTestCase {
    func testA4Is440Hz() {
        XCTAssertEqual(NoteMath.frequency(midi: 69), 440, accuracy: 0.001)
        XCTAssertEqual(NoteMath.nearestMIDINote(frequency: 440), 69)
        XCTAssertEqual(NoteMath.name(midi: 69), "A4")
    }

    func testOctaveAndCents() {
        XCTAssertEqual(NoteMath.frequency(midi: 81), 880, accuracy: 0.001)
        XCTAssertEqual(NoteMath.cents(frequency: 440 * pow(2, 50.0 / 1200), midi: 69), 50, accuracy: 0.01)
    }

    func testInvalidFrequencyHasNoNote() {
        XCTAssertNil(NoteMath.nearestMIDINote(frequency: 0))
        XCTAssertNil(NoteMath.nearestMIDINote(frequency: -.infinity))
    }
}
