import UniformTypeIdentifiers

enum FileImportTypes {
    // Some Files providers expose downloaded SVP/MIDI files as dynamic UTIs.
    // Let the system picker select any file, then validate the extension here.
    static let allowed: [UTType] = [.item]
    static let lyrics: [UTType] = [.item]

    static func isSupportedScoreExtension(_ fileExtension: String) -> Bool {
        ["svp", "mid", "midi", "musicxml", "mxl", "xml", "pdf", "png", "jpg", "jpeg", "heic"].contains(fileExtension.lowercased())
    }

    static func isSupportedLyricsExtension(_ fileExtension: String) -> Bool {
        ["lrc", "txt"].contains(fileExtension.lowercased())
    }
}
