import Foundation
import XCTest
@testable import PitchLab

final class SVPParserTests: XCTestCase {
    func testUserScoreKeepsAllNotesAndTiming() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "vocal-sample", withExtension: "svp"))
        let score = try SVPParser.parse(data: Data(contentsOf: url))

        XCTAssertEqual(score.title, "主人声")
        XCTAssertEqual(score.notes.count, 260)
        XCTAssertEqual(score.notes.map(\.midi).min(), 49)
        XCTAssertEqual(score.notes.map(\.midi).max(), 73)
        XCTAssertEqual(score.beatDuration, 60 / 92.936, accuracy: 0.000001)
        XCTAssertEqual(score.notes.first?.onset ?? -1, 13.05, accuracy: 0.000001)
        XCTAssertEqual(score.notes.first?.duration ?? -1, 0.65, accuracy: 0.000001)
        XCTAssertEqual(score.notes.first?.lyric, "la")
        XCTAssertEqual(score.notes.last?.onset ?? -1, 214.42, accuracy: 0.000001)
        XCTAssertEqual(score.notes.last?.duration ?? -1, 0.1625, accuracy: 0.000001)
        XCTAssertTrue(zip(score.notes, score.notes.dropFirst()).allSatisfy { pair in pair.0.onset <= pair.1.onset })
    }

    func testTempoChangeSplitsNoteDurationAcrossSegments() throws {
        let json = """
        {"version":153,"time":{"tempo":[{"position":0,"bpm":120},{"position":705600000,"bpm":60}]},
         "tracks":[{"name":"Vocal","mainGroup":{"notes":[
           {"onset":352800000,"duration":1058400000,"pitch":60,"lyrics":"ah"}]}}]}
        """
        let score = try SVPParser.parse(data: Data(json.utf8))
        XCTAssertEqual(score.beatDuration, 0.5)
        XCTAssertEqual(score.notes[0].onset, 0.25, accuracy: 0.000001)
        XCTAssertEqual(score.notes[0].duration, 1.25, accuracy: 0.000001)
    }

    func testSelectsFirstSingingTrackAndAppliesMainRefOffsets() throws {
        let json = """
        {"version":153,"time":{"tempo":[{"position":0,"bpm":120}]},"tracks":[
          {"name":"Empty","mainGroup":{"notes":[]}},
          {"name":"Vocal","mainRef":{"blickOffset":705600000,"pitchOffset":2},
           "mainGroup":{"notes":[{"onset":0,"duration":705600000,"pitch":60,"lyrics":"oh"}]}}]}
        """
        let score = try SVPParser.parse(data: Data(json.utf8))
        XCTAssertEqual(score.title, "Vocal")
        XCTAssertEqual(score.notes, [VocalNote(onset: 0.5, duration: 0.5, midi: 62, lyric: "oh",
                                               beatOnset: 1, beatDuration: 1)])
    }

    func testPhraseGapUsesQuarterNotesAfterTempoChange() throws {
        let json = """
        {"version":153,"time":{"tempo":[{"position":0,"bpm":120},{"position":705600000,"bpm":60}]},
         "tracks":[{"name":"Vocal","mainGroup":{"notes":[
           {"onset":705600000,"duration":705600000,"pitch":60},
           {"onset":2469600000,"duration":705600000,"pitch":62}]}}]}
        """
        let score = try SVPParser.parse(data: Data(json.utf8))
        XCTAssertEqual(score.notes[0].beatOnset, 1)
        XCTAssertEqual(score.notes[1].beatOnset, 3.5)
        XCTAssertEqual(PhraseBuilder.make(score: score).count, 1)
    }

    func testRejectsExtremeTemposThatCannotProduceFinitePositiveTiming() {
        for bpm in ["1e308", "1e-308"] {
            let json = """
            {"version":153,"time":{"tempo":[{"position":0,"bpm":\(bpm)}]},
             "tracks":[{"mainGroup":{"notes":[
               {"onset":0,"duration":705600000,"pitch":60}]}}]}
            """
            XCTAssertThrowsError(try SVPParser.parse(data: Data(json.utf8)), bpm)
        }
    }

    func testRejectsMalformedUnsupportedEmptyAndInvalidDuration() {
        let badFiles = [
            "not json",
            "{\"version\":1,\"time\":{\"tempo\":[{\"position\":0,\"bpm\":120}]},\"tracks\":[]}",
            "{\"version\":153,\"time\":{\"tempo\":[{\"position\":0,\"bpm\":120}]},\"tracks\":[{\"mainGroup\":{\"notes\":[]}}]}",
            "{\"version\":153,\"time\":{\"tempo\":[{\"position\":0,\"bpm\":120}]},\"tracks\":[{\"mainGroup\":{\"notes\":[{\"onset\":0,\"duration\":0,\"pitch\":60}]}}]}",
            "{\"version\":153,\"time\":{\"tempo\":[{\"position\":0,\"bpm\":0}]},\"tracks\":[{\"mainGroup\":{\"notes\":[{\"onset\":0,\"duration\":705600000,\"pitch\":60}]}}]}"
        ]
        for file in badFiles {
            XCTAssertThrowsError(try SVPParser.parse(data: Data(file.utf8)), file)
        }
    }
}
