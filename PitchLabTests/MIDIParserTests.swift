import Foundation
import XCTest
@testable import PitchLab

final class MIDIParserTests: XCTestCase {
    func testSampleVocalTrackHasExpectedNotesAndRange() throws {
        let encoded = "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"
        let score = try MIDIParser.parse(data: XCTUnwrap(Data(base64Encoded: encoded)))
        XCTAssertEqual(score.notes.count, 260)
        XCTAssertEqual(score.notes.map(\.midi).min(), 49)
        XCTAssertEqual(score.notes.map(\.midi).max(), 73)
        XCTAssertEqual(score.title, "Vocal")
        XCTAssertTrue(zip(score.notes, score.notes.dropFirst()).allSatisfy { $0.0.onset <= $0.1.onset })
        XCTAssertTrue(score.notes.allSatisfy { $0.duration > 0 })
    }

    func testPrefersVocalTrackAndAppliesTempoMapAcrossTracks() throws {
        let tempo = track([0, 0xFF, 0x51, 3, 0x07, 0xA1, 0x20,
                           0x83, 0x60, 0xFF, 0x51, 3, 0x0F, 0x42, 0x40,
                           0, 0xFF, 0x2F, 0])
        let accompaniment = track([0, 0x90, 48, 100, 0x87, 0x40, 0x80, 48, 0,
                                   0, 0xFF, 0x2F, 0])
        let vocal = track([0, 0xFF, 3, 5, 86, 111, 99, 97, 108,
                           0, 0x90, 60, 90,
                           0x83, 0x60, 0x80, 60, 0,
                           0, 0x90, 62, 90,
                           0x83, 0x60, 0x80, 62, 0,
                           0, 0xFF, 0x2F, 0])
        let score = try MIDIParser.parse(data: midi([tempo, accompaniment, vocal]))
        XCTAssertEqual(score.notes.map(\.midi), [60, 62])
        XCTAssertEqual(score.notes[0].onset, 0, accuracy: 0.0001)
        XCTAssertEqual(score.notes[0].duration, 0.5, accuracy: 0.0001)
        XCTAssertEqual(score.notes[1].onset, 0.5, accuracy: 0.0001)
        XCTAssertEqual(score.notes[1].duration, 1, accuracy: 0.0001)
        XCTAssertEqual(score.beatDuration, 0.5, accuracy: 0.0001)
    }

    func testRunningStatusVelocityZeroAndFirstMelodyFallback() throws {
        let first = track([0, 0x90, 64, 80,
                           0x81, 0x70, 64, 0,
                           0, 67, 80,
                           0x81, 0x70, 67, 0,
                           0, 0xFF, 0x2F, 0])
        let second = track([0, 0x90, 72, 80, 0x81, 0x70, 0x80, 72, 0,
                            0, 0xFF, 0x2F, 0])
        let score = try MIDIParser.parse(data: midi([first, second]))
        XCTAssertEqual(score.notes.map(\.midi), [64, 67])
        XCTAssertEqual(score.notes.map(\.duration), [0.25, 0.25])
    }

    func testPairsOverlappingSamePitchInStartOrder() throws {
        let notes = track([0, 0x90, 60, 80,
                           0x81, 0x70, 60, 80,
                           0x81, 0x70, 0x80, 60, 0,
                           0x81, 0x70, 60, 0,
                           0, 0xFF, 0x2F, 0])
        let score = try MIDIParser.parse(data: midi([notes]))
        XCTAssertEqual(score.notes.count, 2)
        XCTAssertEqual(score.notes[0].onset, 0, accuracy: 0.0001)
        XCTAssertEqual(score.notes[0].duration, 0.5, accuracy: 0.0001)
        XCTAssertEqual(score.notes[1].onset, 0.25, accuracy: 0.0001)
        XCTAssertEqual(score.notes[1].duration, 0.5, accuracy: 0.0001)
    }

    func testRejectsTruncatedAndUnsupportedFiles() {
        XCTAssertThrowsError(try MIDIParser.parse(data: Data([0x4D, 0x54, 0x68, 0x64])))
        XCTAssertThrowsError(try MIDIParser.parse(data: midi([track([0, 0x90, 60])])))
        XCTAssertThrowsError(try MIDIParser.parse(data: midi([track([0, 0xFF, 0x2F, 0])], division: 0xE728)))
    }

    func testRejectsTrackWithoutCompleteNotes() {
        let empty = track([0, 0xFF, 0x2F, 0])
        XCTAssertThrowsError(try MIDIParser.parse(data: midi([empty])))
    }

    private func midi(_ tracks: [[UInt8]], division: UInt16 = 480) -> Data {
        var bytes: [UInt8] = [0x4D, 0x54, 0x68, 0x64, 0, 0, 0, 6,
                              0, tracks.count > 1 ? 1 : 0,
                              UInt8(tracks.count >> 8), UInt8(tracks.count & 0xFF),
                              UInt8(division >> 8), UInt8(division & 0xFF)]
        for body in tracks { bytes += body }
        return Data(bytes)
    }

    private func track(_ body: [UInt8]) -> [UInt8] {
        let size = body.count
        return [0x4D, 0x54, 0x72, 0x6B,
                UInt8((size >> 24) & 0xFF), UInt8((size >> 16) & 0xFF),
                UInt8((size >> 8) & 0xFF), UInt8(size & 0xFF)] + body
    }
}
