import XCTest
@testable import PitchLab

final class PhraseScoringTests: XCTestCase {
    private let score = VocalScore(notes: [
        VocalNote(onset: 1, duration: 0.5, midi: 60, lyric: nil),
        VocalNote(onset: 1.5, duration: 0.5, midi: 62, lyric: nil),
        VocalNote(onset: 2, duration: 0.5, midi: 64, lyric: nil)
    ], title: "歌", beatDuration: 0.5)

    private var phrase: VocalPhrase {
        VocalPhrase(id: 0, noteRange: 0..<3, start: 1, end: 2.5, text: "第一句")
    }

    func testPassesOnlyWhenEveryNoteIsAccurate() {
        let readings = samples(onset: 1, midi: 60, cents: 10)
            + samples(onset: 1.5, midi: 62, cents: -20)
            + samples(onset: 2, midi: 64, cents: 35)
        let result = PhraseScoring.evaluate(score: score, phrase: phrase, readings: readings, transposition: 0)

        XCTAssertTrue(result.passed)
        XCTAssertEqual(result.notes.map(\.status), [.passed, .passed, .passed])
    }

    func testIdentifiesHighLowAndMissingNotesForRetry() {
        let readings = samples(onset: 1, midi: 60, cents: 90)
            + samples(onset: 1.5, midi: 62, cents: -90)
        let result = PhraseScoring.evaluate(score: score, phrase: phrase, readings: readings, transposition: 0)

        XCTAssertFalse(result.passed)
        XCTAssertEqual(result.notes.map(\.status), [.high, .low, .missed])
        XCTAssertEqual(result.notes.map(\.noteIndex), [0, 1, 2])
    }

    func testTransitionSamplesAndShortSoundDoNotPass() {
        let readings = [TimedPitchReading(time: 1.01, frequency: NoteMath.frequency(midi: 60))]
            + [TimedPitchReading(time: 1.25, frequency: NoteMath.frequency(midi: 60))]
        let result = PhraseScoring.evaluate(score: score, phrase: phrase, readings: readings, transposition: 0)
        XCTAssertEqual(result.notes[0].status, .missed)
    }

    func testTranspositionChangesTargetPitch() {
        let readings = samples(onset: 1, midi: 62, cents: 0)
        let result = PhraseScoring.evaluate(score: score, phrase: phrase, readings: readings, transposition: 2)
        XCTAssertEqual(result.notes[0].status, .passed)
        XCTAssertEqual(result.notes[0].targetMIDI, 62)
    }

    private func samples(onset: Double, midi: Int, cents: Double) -> [TimedPitchReading] {
        let frequency = NoteMath.frequency(midi: midi) * pow(2, cents / 1200)
        return [0.1, 0.2, 0.3, 0.4].map { TimedPitchReading(time: onset + $0, frequency: frequency) }
    }
}
