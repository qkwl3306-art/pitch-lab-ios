import Foundation

enum ScoreImportError: LocalizedError {
    case unsupportedFormat
    case invalidMusicXML
    case noMelody
    case invalidMXL
    case unsafeArchivePath
    case fileTooLarge
    case invalidPDF
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat: String(localized: "不支持这种乐谱文件格式")
        case .invalidMusicXML: String(localized: "MusicXML 文件无法读取")
        case .noMelody: String(localized: "乐谱中没有可练习的单声部音符")
        case .invalidMXL: String(localized: "MXL 压缩乐谱无法读取")
        case .unsafeArchivePath: String(localized: "压缩乐谱包含不安全的文件路径")
        case .fileTooLarge: String(localized: "乐谱文件过大")
        case .invalidPDF: String(localized: "PDF 乐谱无法打开")
        case .invalidImage: String(localized: "乐谱图片无法打开")
        }
    }
}
