import Combine
import Foundation
import PDFKit
import UIKit

enum ScoreKind: String, Codable, Hashable {
    case musicXML
    case pdf
    case image
}

struct StoredScore: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let fileName: String
    let kind: ScoreKind
    let notes: [Int]
}

@MainActor
final class ScoreStore: ObservableObject {
    @Published private(set) var items: [StoredScore] = []

    private let directory: URL
    private let manifestURL: URL

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        directory = documents.appendingPathComponent("ImportedScores", isDirectory: true)
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
        let data = try Data(contentsOf: source)
        guard data.count <= 15_000_000 else { throw ScoreImportError.fileTooLarge }
        let ext = source.pathExtension.lowercased()
        let name = source.deletingPathExtension().lastPathComponent
        switch ext {
        case "musicxml", "xml":
            let notes = try MusicXMLParser.parse(data: data)
            return try add(data: data, name: name, kind: .musicXML, notes: notes, ext: "musicxml")
        case "mxl":
            let xml = try MXLLoader.load(data: data)
            let notes = try MusicXMLParser.parse(data: xml)
            return try add(data: data, name: name, kind: .musicXML, notes: notes, ext: "mxl")
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

    private func add(data: Data, name: String, kind: ScoreKind, notes: [Int], ext: String) throws -> StoredScore {
        let id = UUID()
        let fileName = "\(id.uuidString).\(ext)"
        let destination = directory.appendingPathComponent(fileName)
        try data.write(to: destination, options: .atomic)
        let score = StoredScore(id: id, name: name.isEmpty ? "未命名乐谱" : name, fileName: fileName, kind: kind, notes: notes)
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
