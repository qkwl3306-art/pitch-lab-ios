import UniformTypeIdentifiers

enum FileImportTypes {
    static let svp = UTType(importedAs: "com.qkwl3306art.pitchlab.svp")
    static let musicXML = UTType(importedAs: "com.qkwl3306art.pitchlab.musicxml")
    static let mxl = UTType(importedAs: "com.qkwl3306art.pitchlab.mxl")
    static let lrc = UTType(importedAs: "com.qkwl3306art.pitchlab.lrc")

    static let allowed: [UTType] = [.pdf, .xml, .image, .midi, svp, musicXML, mxl]
    static let lyrics: [UTType] = [.plainText, lrc]
}
