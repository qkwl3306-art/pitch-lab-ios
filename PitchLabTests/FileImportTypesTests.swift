import UniformTypeIdentifiers
import XCTest
@testable import PitchLab

final class FileImportTypesTests: XCTestCase {
    func testDocumentPickerUsesUnrestrictedItemTypeAndValidatesAfterSelection() {
        XCTAssertEqual(FileImportTypes.allowed.map(\.identifier), [UTType.item.identifier])
        XCTAssertTrue(FileImportTypes.isSupportedScoreExtension("svp"))
        XCTAssertTrue(FileImportTypes.isSupportedScoreExtension("mid"))
        XCTAssertFalse(FileImportTypes.isSupportedScoreExtension("zip"))
    }

    func testPickerAcceptsVocalScoreAndExistingScoreExtensions() throws {
        for ext in ["svp", "mid", "midi", "musicxml", "mxl", "xml", "pdf", "png"] {
            let type = try XCTUnwrap(UTType(filenameExtension: ext), ext)
            XCTAssertTrue(FileImportTypes.allowed.contains { type.conforms(to: $0) }, ext)
        }
    }

    func testLyricsPickerAcceptsLRCAndTXT() throws {
        for ext in ["lrc", "txt"] {
            let type = try XCTUnwrap(UTType(filenameExtension: ext), ext)
            XCTAssertTrue(FileImportTypes.lyrics.contains { type.conforms(to: $0) }, ext)
        }
    }
}
