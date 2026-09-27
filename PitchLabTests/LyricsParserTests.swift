import XCTest
@testable import PitchLab

final class LyricsParserTests: XCTestCase {
    func testLRCParsesChineseLinesAndMultipleTimestamps() throws {
        let data = "[ti:测试]\n[00:01.50]第一句\n[00:03.000][00:06.25]第二句\n".data(using: .utf8)!
        let lines = try LyricsParser.parseLRC(data: data)
        XCTAssertEqual(lines.map(\.text), ["第一句", "第二句", "第二句"])
        XCTAssertEqual(lines.map(\.time), [1.5, 3, 6.25])
    }

    func testTXTUsesNonemptyLinesInOrder() throws {
        let data = "第一句\n\n 第二句 \n".data(using: .utf8)!
        XCTAssertEqual(try LyricsParser.parseTXT(data: data).map(\.text), ["第一句", "第二句"])
    }

    func testLRCWithoutTimedLyricsFails() {
        let data = "[ti:测试]\n没有时间".data(using: .utf8)!
        XCTAssertThrowsError(try LyricsParser.parseLRC(data: data))
    }
}
