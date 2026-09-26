import Foundation
import ZIPFoundation

enum MXLLoader {
    static func load(url: URL) throws -> Data {
        try load(data: Data(contentsOf: url))
    }

    static func load(data: Data) throws -> Data {
        guard let archive = try? Archive(data: data, accessMode: .read),
              let containerEntry = archive["META-INF/container.xml"] else {
            throw ScoreImportError.invalidMXL
        }
        let container = try extract(containerEntry, from: archive, limit: 1_000_000)
        let locator = ContainerDelegate()
        let parser = XMLParser(data: container)
        parser.delegate = locator
        parser.shouldResolveExternalEntities = false
        guard parser.parse(), let path = locator.rootPath else { throw ScoreImportError.invalidMXL }
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !path.hasPrefix("/"), !path.contains("\\"),
              !components.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else {
            throw ScoreImportError.unsafeArchivePath
        }
        guard let scoreEntry = archive[path] else { throw ScoreImportError.invalidMXL }
        return try extract(scoreEntry, from: archive, limit: 10_000_000)
    }

    private static func extract(_ entry: Entry, from archive: Archive, limit: Int) throws -> Data {
        var output = Data()
        try archive.extract(entry, consumer: { chunk in
            guard output.count + chunk.count <= limit else { throw ScoreImportError.fileTooLarge }
            output.append(chunk)
        })
        return output
    }
}

private final class ContainerDelegate: NSObject, XMLParserDelegate {
    private(set) var rootPath: String?

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        if name == "rootfile", rootPath == nil { rootPath = attributes["full-path"] }
    }
}
