import Foundation

enum MusicXMLParser {
    static func parse(data: Data) throws -> [Int] {
        let delegate = MelodyDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false
        guard parser.parse(), delegate.rootName == "score-partwise" else {
            throw ScoreImportError.invalidMusicXML
        }
        guard !delegate.notes.isEmpty else { throw ScoreImportError.noMelody }
        return delegate.notes
    }
}

private final class MelodyDelegate: NSObject, XMLParserDelegate {
    private(set) var rootName: String?
    private(set) var notes: [Int] = []
    private var partCount = 0
    private var inFirstPart = false
    private var inNote = false
    private var isRest = false
    private var isChord = false
    private var step: String?
    private var alter = 0
    private var octave: Int?
    private var voice: String?
    private var selectedVoice: String?
    private var field: String?
    private var fieldText = ""

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        if rootName == nil { rootName = name }
        if name == "part" {
            partCount += 1
            inFirstPart = partCount == 1
        }
        guard inFirstPart else { return }
        if name == "note" {
            inNote = true
            isRest = false
            isChord = false
            step = nil
            alter = 0
            octave = nil
            voice = nil
        } else if inNote {
            if name == "rest" { isRest = true }
            if name == "chord" { isChord = true }
            if ["step", "alter", "octave", "voice"].contains(name) {
                field = name
                fieldText = ""
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if field != nil { fieldText += string }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        if let field, name == field {
            let text = fieldText.trimmingCharacters(in: .whitespacesAndNewlines)
            switch name {
            case "step": step = text
            case "alter": alter = Int(text) ?? 0
            case "octave": octave = Int(text)
            case "voice": voice = text
            default: break
            }
            self.field = nil
        }
        if name == "note", inNote {
            let noteVoice = voice ?? "1"
            if selectedVoice == nil { selectedVoice = noteVoice }
            if selectedVoice == noteVoice, !isRest, !isChord, let step, let octave {
                let semitones = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
                if let base = semitones[step] {
                    let midi = (octave + 1) * 12 + base + alter
                    if (0...127).contains(midi) { notes.append(midi) }
                }
            }
            inNote = false
        }
        if name == "part" { inFirstPart = false }
    }
}
