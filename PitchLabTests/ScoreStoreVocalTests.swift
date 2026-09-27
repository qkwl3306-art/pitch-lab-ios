import Foundation
import XCTest
@testable import PitchLab

@MainActor
final class ScoreStoreVocalTests: XCTestCase {
    func testSVPImportKeepsTimedNotesAndPhrases() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ScoreStore(directory: directory)
        let source = try XCTUnwrap(Bundle(for: SVPParserTests.self).url(forResource: "vocal-sample", withExtension: "svp"))
        let imported = try store.importFile(at: source)

        XCTAssertEqual(imported.kind, .vocal)
        XCTAssertEqual(imported.vocalScore?.notes.count, 260)
        XCTAssertEqual(imported.notes.count, 260)
        XCTAssertFalse(imported.phrases.isEmpty)
        XCTAssertEqual(ScoreStore(directory: directory).items.first?.vocalScore?.notes.count, 260)
    }

    func testLyricsAttachToImportedVocalScore() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ScoreStore(directory: directory)
        let source = try XCTUnwrap(Bundle(for: SVPParserTests.self).url(forResource: "vocal-sample", withExtension: "svp"))
        let imported = try store.importFile(at: source)
        let lyricURL = directory.appendingPathComponent("words.txt")
        try "第一句\n第二句".write(to: lyricURL, atomically: true, encoding: .utf8)

        let updated = try store.importLyrics(at: lyricURL, for: imported)
        XCTAssertEqual(updated.phrases.first?.text, "第一句")
        XCTAssertEqual(updated.phrases.dropFirst().first?.text, "第二句")
        XCTAssertEqual(ScoreStore(directory: directory).items.first?.phrases.first?.text, "第一句")
    }

    func testOldManifestWithoutVocalFieldsStillLoads() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let id = UUID()
        let filename = "\(id.uuidString).pdf"
        try Data("pdf".utf8).write(to: directory.appendingPathComponent(filename))
        let manifest = """
        [{"id":"\(id.uuidString)","name":"旧乐谱","fileName":"\(filename)","kind":"pdf","notes":[]}]
        """
        try Data(manifest.utf8).write(to: directory.appendingPathComponent("scores.json"))

        let restored = ScoreStore(directory: directory)
        XCTAssertEqual(restored.items.count, 1)
        XCTAssertNil(restored.items[0].vocalScore)
        XCTAssertTrue(restored.items[0].phrases.isEmpty)
    }
}
