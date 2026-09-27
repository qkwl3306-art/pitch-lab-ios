import Foundation

struct LyricLine: Codable, Equatable {
    let time: Double?
    let text: String
}

enum LyricsParseError: LocalizedError {
    case unsupportedEncoding
    case noLyrics

    var errorDescription: String? {
        switch self {
        case .unsupportedEncoding: "歌词文件不是 UTF-8 文本"
        case .noLyrics: "歌词文件没有可用的歌词行"
        }
    }
}

enum LyricsParser {
    private static let timestamp = try! NSRegularExpression(pattern: #"\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]"#)

    static func parseLRC(data: Data) throws -> [LyricLine] {
        guard let source = String(data: data, encoding: .utf8) else { throw LyricsParseError.unsupportedEncoding }
        var result: [LyricLine] = []
        for line in source.components(separatedBy: .newlines) {
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            let matches = timestamp.matches(in: line, range: range)
            guard !matches.isEmpty else { continue }
            let content = timestamp.stringByReplacingMatches(in: line, range: range, withTemplate: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else { continue }
            let nsLine = line as NSString
            for match in matches {
                let minutes = Int(nsLine.substring(with: match.range(at: 1))) ?? 0
                let seconds = Int(nsLine.substring(with: match.range(at: 2))) ?? 0
                guard seconds < 60 else { continue }
                let fraction: Double
                if match.range(at: 3).location != NSNotFound {
                    let digits = nsLine.substring(with: match.range(at: 3))
                    fraction = Double(Int(digits) ?? 0) / pow(10, Double(digits.count))
                } else {
                    fraction = 0
                }
                result.append(LyricLine(time: Double(minutes * 60 + seconds) + fraction, text: content))
            }
        }
        guard !result.isEmpty else { throw LyricsParseError.noLyrics }
        return result.sorted { ($0.time ?? 0) < ($1.time ?? 0) }
    }

    static func parseTXT(data: Data) throws -> [LyricLine] {
        guard let source = String(data: data, encoding: .utf8) else { throw LyricsParseError.unsupportedEncoding }
        let lines = source.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { LyricLine(time: nil, text: $0) }
        guard !lines.isEmpty else { throw LyricsParseError.noLyrics }
        return lines
    }
}
