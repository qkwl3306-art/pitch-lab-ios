import UniformTypeIdentifiers

enum FileImportTypes {
    // Files providers can assign dynamic types to SVP and LRC. Let the user select
    // a file, then validate its extension and contents in ScoreStore/LyricsParser.
    static let allowed: [UTType] = [.item]
    static let lyrics: [UTType] = [.item]
}
