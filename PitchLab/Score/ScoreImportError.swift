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
        case .unsupportedFormat: "不支持这种乐谱文件格式"
        case .invalidMusicXML: "MusicXML 文件无法读取"
        case .noMelody: "乐谱中没有可练习的单声部音符"
        case .invalidMXL: "MXL 压缩乐谱无法读取"
        case .unsafeArchivePath: "压缩乐谱包含不安全的文件路径"
        case .fileTooLarge: "乐谱文件过大"
        case .invalidPDF: "PDF 乐谱无法打开"
        case .invalidImage: "乐谱图片无法打开"
        }
    }
}
