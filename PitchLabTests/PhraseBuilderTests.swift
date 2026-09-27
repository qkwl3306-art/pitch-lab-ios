import XCTest
@testable import PitchLab

final class PhraseBuilderTests: XCTestCase {
    func testTwoBeatRestStartsNewPhrase() {
        let notes = [
            VocalNote(onset: 0, duration: 0.4, midi: 60, lyric: nil),
            VocalNote(onset: 0.5, duration: 0.4, midi: 62, lyric: nil),
            VocalNote(onset: 2.1, duration: 0.4, midi: 64, lyric: nil)
        ]
        let phrases = PhraseBuilder.make(score: VocalScore(notes: notes, title: "歌", beatDuration: 0.5))
        XCTAssertEqual(phrases.map(\.noteRange), [0..<2, 2..<3])
        XCTAssertEqual(phrases.map(\.text), ["第 1 句", "第 2 句"])
    }

    func testLRCMapsByTimeWhileTXTMapsByOrder() {
        let score = VocalScore(notes: [
            VocalNote(onset: 1, duration: 0.5, midi: 60, lyric: nil),
            VocalNote(onset: 4, duration: 0.5, midi: 62, lyric: nil)
        ], title: "歌", beatDuration: 0.5)
        let phrases = PhraseBuilder.make(score: score)
        let lrc = PhraseBuilder.attachLyrics([LyricLine(time: 1.1, text: "甲"), LyricLine(time: 4.1, text: "乙")], to: phrases)
        XCTAssertEqual(lrc.map(\.text), ["甲", "乙"])
        let txt = PhraseBuilder.attachLyrics([LyricLine(time: nil, text: "一"), LyricLine(time: nil, text: "二")], to: phrases)
        XCTAssertEqual(txt.map(\.text), ["一", "二"])
    }
}
