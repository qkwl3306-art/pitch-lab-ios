import XCTest
@testable import PitchLab

final class ToneSequenceRendererTests: XCTestCase {
    func testRenderedPhrasePreservesSilenceOnsetAndAddsGentleBoundedTone() {
        let event = ToneSequenceEvent(midi: 69, onset: 0.1, duration: 0.4)
        let samples = ToneSequenceRenderer.render(events: [event], sampleRate: 8_000)

        XCTAssertEqual(samples.count, 4_960)
        XCTAssertTrue(samples.prefix(800).allSatisfy { $0 == 0 })
        XCTAssertGreaterThan(samples[880...4_000].map(abs).max() ?? 0, 0.8)
        XCTAssertTrue(samples.allSatisfy { $0.isFinite && abs($0) <= 1 })
    }

    func testTranspositionChangesOnlyTheNotePitch() {
        let note = ToneSequenceEvent(midi: 60, onset: 0.25, duration: 0.75)
        let shifted = ToneSequenceRenderer.transposed([note], by: 5)

        XCTAssertEqual(shifted, [ToneSequenceEvent(midi: 65, onset: 0.25, duration: 0.75)])
    }
}
