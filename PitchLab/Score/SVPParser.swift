import Foundation

enum SVPParser {
    fileprivate static let blicksPerQuarter = 705_600_000.0

    static func parse(data: Data) throws -> VocalScore {
        let project: Project
        do {
            project = try JSONDecoder().decode(Project.self, from: data)
        } catch {
            throw SVPParseError.invalidFile
        }
        guard (100..<200).contains(project.version) else {
            throw SVPParseError.unsupportedVersion
        }
        let tempo = try TempoMap(events: project.time.tempo)
        guard let track = project.tracks.first(where: { track in
            track.mainGroup?.notes.contains(where: { $0.musicalType == nil || $0.musicalType == "singing" }) == true
        }), let rawNotes = track.mainGroup?.notes else {
            throw SVPParseError.noSingingNotes
        }

        let offset = track.mainRef?.blickOffset ?? 0
        let pitchOffset = track.mainRef?.pitchOffset ?? 0
        var notes: [(index: Int, note: VocalNote)] = []
        for (index, raw) in rawNotes.enumerated() where raw.musicalType == nil || raw.musicalType == "singing" {
            guard let onset = raw.onset, let duration = raw.duration, let pitch = raw.pitch,
                  onset.isFinite, duration.isFinite, offset.isFinite,
                  duration > 0 else {
                throw SVPParseError.invalidNote
            }
            let absoluteOnset = onset + offset
            let absoluteEnd = absoluteOnset + duration
            let (midi, overflow) = pitch.addingReportingOverflow(pitchOffset)
            guard absoluteOnset.isFinite, absoluteEnd.isFinite, absoluteOnset >= 0,
                  !overflow, (0...127).contains(midi) else {
                throw SVPParseError.invalidNote
            }
            let onsetSeconds = tempo.seconds(at: absoluteOnset)
            let endSeconds = tempo.seconds(at: absoluteEnd)
            guard onsetSeconds.isFinite, endSeconds.isFinite, endSeconds > onsetSeconds else {
                throw SVPParseError.invalidNote
            }
            notes.append((index, VocalNote(onset: onsetSeconds,
                                          duration: endSeconds - onsetSeconds,
                                          midi: midi,
                                          lyric: raw.lyrics,
                                          beatOnset: absoluteOnset / blicksPerQuarter,
                                          beatDuration: duration / blicksPerQuarter)))
        }
        guard !notes.isEmpty else { throw SVPParseError.noSingingNotes }
        notes.sort {
            $0.note.onset == $1.note.onset ? $0.index < $1.index : $0.note.onset < $1.note.onset
        }
        let title = track.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return VocalScore(notes: notes.map { $0.note },
                          title: title.isEmpty ? "Vocal" : title,
                          beatDuration: 60 / tempo.firstBPM)
    }
}

enum SVPParseError: LocalizedError {
    case invalidFile
    case unsupportedVersion
    case noSingingNotes
    case invalidTempo
    case invalidNote

    var errorDescription: String? {
        switch self {
        case .invalidFile: "SVP 文件无法读取"
        case .unsupportedVersion: "不支持这个版本的 SVP 文件"
        case .noSingingNotes: "SVP 文件中没有人声音符"
        case .invalidTempo: "SVP 文件中的速度信息无效"
        case .invalidNote: "SVP 文件中有无效音符"
        }
    }
}

private struct Project: Decodable {
    let version: Int
    let time: Time
    let tracks: [Track]
}

private struct Time: Decodable {
    let tempo: [TempoEvent]
}

private struct TempoEvent: Decodable {
    let position: Double
    let bpm: Double
}

private struct Track: Decodable {
    let name: String?
    let mainGroup: MainGroup?
    let mainRef: MainReference?
}

private struct MainGroup: Decodable {
    let notes: [SVPNote]
}

private struct MainReference: Decodable {
    let blickOffset: Double?
    let pitchOffset: Int?
}

private struct SVPNote: Decodable {
    let musicalType: String?
    let onset: Double?
    let duration: Double?
    let pitch: Int?
    let lyrics: String?
}

private struct TempoMap {
    private struct Segment {
        let position: Double
        let seconds: Double
        let secondsPerBlick: Double
    }

    let firstBPM: Double
    private let segments: [Segment]

    init(events: [TempoEvent]) throws {
        let sorted = events.sorted { $0.position < $1.position }
        guard let first = sorted.first, first.position == 0 else {
            throw SVPParseError.invalidTempo
        }
        var built: [Segment] = []
        for event in sorted {
            guard event.position.isFinite, event.bpm.isFinite, event.bpm > 0,
                  event.position >= 0,
                  built.last?.position != event.position else {
                throw SVPParseError.invalidTempo
            }
            let secondsPerBlick = (60 / event.bpm) / SVPParser.blicksPerQuarter
            guard secondsPerBlick.isFinite, secondsPerBlick > 0 else { throw SVPParseError.invalidTempo }
            let elapsed = built.last.map { previous in
                previous.seconds + (event.position - previous.position) * previous.secondsPerBlick
            } ?? 0
            guard elapsed.isFinite else { throw SVPParseError.invalidTempo }
            built.append(Segment(position: event.position,
                                 seconds: elapsed,
                                 secondsPerBlick: secondsPerBlick))
        }
        firstBPM = first.bpm
        segments = built
    }

    func seconds(at blick: Double) -> Double {
        let segment = segments.last(where: { $0.position <= blick }) ?? segments[0]
        return segment.seconds + (blick - segment.position) * segment.secondsPerBlick
    }
}
