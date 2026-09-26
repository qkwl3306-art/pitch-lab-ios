import XCTest
import ZIPFoundation
@testable import PitchLab

final class MXLLoaderTests: XCTestCase {
    func testLoadsRootMusicXML() throws {
        let score = Data("<score-partwise/>".utf8)
        let archive = try makeArchive(rootPath: "score.xml", score: score)
        XCTAssertEqual(try MXLLoader.load(data: archive), score)
    }

    func testRejectsParentPath() throws {
        let archive = try makeArchive(rootPath: "../score.xml", score: nil)
        XCTAssertThrowsError(try MXLLoader.load(data: archive))
    }

    private func makeArchive(rootPath: String, score: Data?) throws -> Data {
        let archive = try Archive(accessMode: .create)
        let container = Data("""
        <container><rootfiles><rootfile full-path="\(rootPath)"/></rootfiles></container>
        """.utf8)
        try add(container, path: "META-INF/container.xml", to: archive)
        if let score { try add(score, path: "score.xml", to: archive) }
        return archive.data
    }

    private func add(_ data: Data, path: String, to archive: Archive) throws {
        try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(data.count), provider: { position, size in
            data.subdata(in: Int(position)..<(Int(position) + size))
        })
    }
}
