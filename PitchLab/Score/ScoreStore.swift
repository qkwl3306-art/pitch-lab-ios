import Combine
import Foundation
import PDFKit
import UIKit

enum ScoreKind: String, Codable, Hashable {
    case musicXML
    case pdf
    case image
    case vocal
}

struct StoredScore: Identifiable, Codable {
    let id: UUID
    let name: String
    let fileName: String
    let kind: ScoreKind
    let notes: [Int]
    let vocalScore: VocalScore?
    var phrases: [VocalPhrase]

    init(id: UUID, name: String, fileName: String, kind: ScoreKind, notes: [Int],
         vocalScore: VocalScore? = nil, phrases: [VocalPhrase] = []) {
        self.id = id
        self.name = name
        self.fileName = fileName
        self.kind = kind
        self.notes = notes
        self.vocalScore = vocalScore
        self.phrases = phrases
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, fileName, kind, notes, vocalScore, phrases
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        fileName = try values.decode(String.self, forKey: .fileName)
        kind = try values.decode(ScoreKind.self, forKey: .kind)
        notes = try values.decode([Int].self, forKey: .notes)
        vocalScore = try values.decodeIfPresent(VocalScore.self, forKey: .vocalScore)
        phrases = try values.decodeIfPresent([VocalPhrase].self, forKey: .phrases) ?? []
    }
}

@MainActor
final class ScoreStore: ObservableObject {
    @Published private(set) var items: [StoredScore] = []

    private let directory: URL
    private let manifestURL: URL

    init(directory customDirectory: URL? = nil) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        directory = customDirectory ?? documents.appendingPathComponent("ImportedScores", isDirectory: true)
        manifestURL = directory.appendingPathComponent("scores.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: manifestURL),
           let stored = try? JSONDecoder().decode([StoredScore].self, from: data) {
            items = stored.filter { FileManager.default.fileExists(atPath: directory.appendingPathComponent($0.fileName).path) }
        }
    }

    func url(for score: StoredScore) -> URL {
        directory.appendingPathComponent(score.fileName)
    }

    @discardableResult
    func importFile(at source: URL) throws -> StoredScore {
        let access = source.startAccessingSecurityScopedResource()
        defer { if access { source.stopAccessingSecurityScopedResource() } }
        let ext = source.pathExtension.lowercased()
        guard ["musicxml", "xml", "mxl", "svp", "mid", "midi", "pdf",
               "jpg", "jpeg", "png", "heic"].contains(ext) else {
            throw ScoreImportError.unsupportedFormat
        }
        if let size = try? source.resourceValues(forKeys: [.fileSizeKey]).fileSize,
           size > 15_000_000 { throw ScoreImportError.fileTooLarge }
        let data = try Data(contentsOf: source)
        guard data.count <= 15_000_000 else { throw ScoreImportError.fileTooLarge }
        let name = source.deletingPathExtension().lastPathComponent
        switch ext {
        case "musicxml", "xml":
            let notes = try MusicXMLParser.parse(data: data)
            return try add(data: data, name: name, kind: .musicXML, notes: notes, ext: "musicxml")
        case "mxl":
            let xml = try MXLLoader.load(data: data)
            let notes = try MusicXMLParser.parse(data: xml)
            return try add(data: data, name: name, kind: .musicXML, notes: notes, ext: "mxl")
        case "svp":
            let vocal = try SVPParser.parse(data: data)
            return try add(data: data, name: name, kind: .vocal, notes: vocal.notes.map(\.midi),
                           ext: "svp", vocalScore: vocal, phrases: PhraseBuilder.make(score: vocal))
        case "mid", "midi":
            let vocal = try MIDIParser.parse(data: data)
            return try add(data: data, name: name, kind: .vocal, notes: vocal.notes.map(\.midi),
                           ext: ext, vocalScore: vocal, phrases: PhraseBuilder.make(score: vocal))
        case "pdf":
            guard let document = PDFDocument(data: data), document.pageCount > 0 else { throw ScoreImportError.invalidPDF }
            return try add(data: data, name: name, kind: .pdf, notes: [], ext: "pdf")
        case "jpg", "jpeg", "png", "heic":
            guard let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.9) else { throw ScoreImportError.invalidImage }
            return try add(data: jpeg, name: name, kind: .image, notes: [], ext: "jpg")
        default:
            throw ScoreImportError.unsupportedFormat
        }
    }

    @discardableResult
    func importImage(_ data: Data, name: String = "照片乐谱") throws -> StoredScore {
        guard let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.9) else {
            throw ScoreImportError.invalidImage
        }
        return try add(data: jpeg, name: name, kind: .image, notes: [], ext: "jpg")
    }

    func remove(_ score: StoredScore) {
        try? FileManager.default.removeItem(at: url(for: score))
        items.removeAll { $0.id == score.id }
        try? saveManifest()
    }

    @discardableResult
    func importLyrics(at source: URL, for score: StoredScore) throws -> StoredScore {
        let access = source.startAccessingSecurityScopedResource()
        defer { if access { source.stopAccessingSecurityScopedResource() } }
        let ext = source.pathExtension.lowercased()
        guard ext == "lrc" || ext == "txt" else { throw ScoreImportError.unsupportedFormat }
        if let size = try? source.resourceValues(forKeys: [.fileSizeKey]).fileSize,
           size > 1_000_000 { throw ScoreImportError.fileTooLarge }
        let data = try Data(contentsOf: source)
        guard data.count <= 1_000_000 else { throw ScoreImportError.fileTooLarge }
        let lines: [LyricLine]
        switch ext {
        case "lrc": lines = try LyricsParser.parseLRC(data: data)
        case "txt": lines = try LyricsParser.parseTXT(data: data)
        default: throw ScoreImportError.unsupportedFormat
        }
        return try setLyrics(lines, for: score)
    }

    @discardableResult
    func setLyrics(_ lines: [LyricLine], for score: StoredScore) throws -> StoredScore {
        guard score.kind == .vocal, let index = items.firstIndex(where: { $0.id == score.id }) else {
            throw ScoreImportError.noMelody
        }
        let previous = items[index]
        items[index].phrases = PhraseBuilder.attachLyrics(lines, to: previous.phrases)
        do {
            try saveManifest()
        } catch {
            items[index] = previous
            throw error
        }
        return items[index]
    }

    @discardableResult
    func updatePhrases(_ phrases: [VocalPhrase], for score: StoredScore) throws -> StoredScore {
        guard let index = items.firstIndex(where: { $0.id == score.id }) else { throw ScoreImportError.noMelody }
        let previous = items[index]
        items[index].phrases = phrases
        do { try saveManifest() } catch {
            items[index] = previous
            throw error
        }
        return items[index]
    }

    private func add(data: Data, name: String, kind: ScoreKind, notes: [Int], ext: String,
                     vocalScore: VocalScore? = nil, phrases: [VocalPhrase] = []) throws -> StoredScore {
        let id = UUID()
        let fileName = "\(id.uuidString).\(ext)"
        let destination = directory.appendingPathComponent(fileName)
        try data.write(to: destination, options: .atomic)
        let score = StoredScore(id: id, name: name.isEmpty ? "未命名乐谱" : name, fileName: fileName,
                                kind: kind, notes: notes, vocalScore: vocalScore, phrases: phrases)
        items.insert(score, at: 0)
        do {
            try saveManifest()
        } catch {
            items.removeAll { $0.id == id }
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
        return score
    }

    private func saveManifest() throws {
        try JSONEncoder().encode(items).write(to: manifestURL, options: .atomic)
    }
}
