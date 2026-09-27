import Foundation

enum MIDIParseError: LocalizedError {
    case invalidFile
    case unsupportedTiming
    case noNotes

    var errorDescription: String? {
        switch self {
        case .invalidFile: "MIDI 文件损坏或格式无法识别"
        case .unsupportedTiming: "暂不支持这种 MIDI 时间格式"
        case .noNotes: "MIDI 文件中没有可练习的音符"
        }
    }
}

enum MIDIParser {
    static func parse(data: Data) throws -> VocalScore {
        var reader = MIDIReader(bytes: Array(data))
        guard try reader.read(count: 4) == [0x4D, 0x54, 0x68, 0x64] else {
            throw MIDIParseError.invalidFile
        }
        let headerLength = try reader.readUInt32()
        guard headerLength >= 6, headerLength <= reader.remaining else {
            throw MIDIParseError.invalidFile
        }
        let format = try reader.readUInt16()
        let trackCount = Int(try reader.readUInt16())
        let division = try reader.readUInt16()
        guard format <= 1, trackCount > 0, (format != 0 || trackCount == 1) else {
            throw MIDIParseError.invalidFile
        }
        guard division & 0x8000 == 0, division != 0 else {
            throw MIDIParseError.unsupportedTiming
        }
        try reader.skip(count: headerLength - 6)

        var tracks: [MIDITrack] = []
        var tempos: [MIDITempo] = []
        for index in 0..<trackCount {
            guard try reader.read(count: 4) == [0x4D, 0x54, 0x72, 0x6B] else {
                throw MIDIParseError.invalidFile
            }
            let length = try reader.readUInt32()
            let bytes = try reader.read(count: length)
            let track = try parseTrack(bytes, index: index)
            tracks.append(track)
            tempos += track.tempos
        }

        guard let selected = tracks.first(where: { !$0.notes.isEmpty && $0.name?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "vocal" })
                ?? tracks.first(where: { !$0.notes.isEmpty }) else {
            throw MIDIParseError.noNotes
        }
        let tempoMap = MIDITempoMap(tempos: tempos, ticksPerQuarter: Int(division))
        let notes = selected.notes.sorted {
            if $0.start == $1.start { return $0.end < $1.end }
            return $0.start < $1.start
        }.map {
            VocalNote(onset: tempoMap.seconds(at: $0.start),
                      duration: tempoMap.seconds(at: $0.end) - tempoMap.seconds(at: $0.start),
                      midi: $0.pitch, lyric: nil)
        }
        return VocalScore(notes: notes, title: selected.name ?? "MIDI Melody",
                          beatDuration: Double(tempoMap.initialMicrosecondsPerQuarter) / 1_000_000)
    }

    private static func parseTrack(_ bytes: [UInt8], index: Int) throws -> MIDITrack {
        var reader = MIDIReader(bytes: bytes)
        var tick = 0
        var runningStatus: UInt8?
        var name: String?
        var notes: [MIDINoteTicks] = []
        var tempos: [MIDITempo] = []
        var active: [Int: [Int]] = [:]
        while reader.remaining > 0 {
            let delta = try reader.readVariableLength()
            guard tick <= Int.max - delta else { throw MIDIParseError.invalidFile }
            tick += delta
            let first = try reader.readByte()
            let status: UInt8
            let firstData: UInt8?
            if first & 0x80 != 0 {
                status = first
                firstData = nil
                if status < 0xF0 { runningStatus = status }
            } else {
                guard let saved = runningStatus else { throw MIDIParseError.invalidFile }
                status = saved
                firstData = first
            }

            if status == 0xFF {
                let kind = try reader.readByte()
                let length = try reader.readVariableLength()
                let payload = try reader.read(count: length)
                if kind == 0x03 {
                    name = String(bytes: payload, encoding: .utf8)
                        ?? String(bytes: payload, encoding: .isoLatin1)
                } else if kind == 0x51 {
                    guard payload.count == 3 else { throw MIDIParseError.invalidFile }
                    let microseconds = Int(payload[0]) << 16 | Int(payload[1]) << 8 | Int(payload[2])
                    guard microseconds > 0 else { throw MIDIParseError.invalidFile }
                    tempos.append(MIDITempo(tick: tick, microsecondsPerQuarter: microseconds,
                                            track: index, order: tempos.count))
                } else if kind == 0x2F {
                    guard payload.isEmpty else { throw MIDIParseError.invalidFile }
                    break
                }
                continue
            }
            if status == 0xF0 || status == 0xF7 {
                let length = try reader.readVariableLength()
                try reader.skip(count: length)
                runningStatus = nil
                continue
            }
            guard status < 0xF0 else { throw MIDIParseError.invalidFile }
            let command = status & 0xF0
            let channel = Int(status & 0x0F)
            let data1 = try firstData ?? reader.readByte()
            let data2: UInt8?
            if command == 0xC0 || command == 0xD0 {
                data2 = nil
            } else {
                data2 = try reader.readByte()
            }
            guard data1 < 0x80, data2.map({ $0 < 0x80 }) ?? true else {
                throw MIDIParseError.invalidFile
            }
            let key = channel * 128 + Int(data1)
            if command == 0x90, let velocity = data2, velocity > 0 {
                active[key, default: []].append(tick)
            } else if command == 0x80 || (command == 0x90 && data2 == 0) {
                if var starts = active[key], !starts.isEmpty {
                    let start = starts.removeFirst()
                    active[key] = starts
                    if tick > start { notes.append(MIDINoteTicks(start: start, end: tick, pitch: Int(data1))) }
                }
            }
        }
        return MIDITrack(name: name, notes: notes, tempos: tempos)
    }
}

private struct MIDINoteTicks {
    let start: Int
    let end: Int
    let pitch: Int
}

private struct MIDITempo {
    let tick: Int
    let microsecondsPerQuarter: Int
    let track: Int
    let order: Int
}

private struct MIDITrack {
    let name: String?
    let notes: [MIDINoteTicks]
    let tempos: [MIDITempo]
}

private struct MIDITempoMap {
    let ticksPerQuarter: Int
    let changes: [MIDITempo]
    let initialMicrosecondsPerQuarter: Int

    init(tempos: [MIDITempo], ticksPerQuarter: Int) {
        self.ticksPerQuarter = ticksPerQuarter
        changes = tempos.sorted {
            if $0.tick != $1.tick { return $0.tick < $1.tick }
            if $0.track != $1.track { return $0.track < $1.track }
            return $0.order < $1.order
        }
        initialMicrosecondsPerQuarter = changes.last(where: { $0.tick == 0 })?.microsecondsPerQuarter ?? 500_000
    }

    func seconds(at tick: Int) -> Double {
        var elapsed = 0.0
        var previousTick = 0
        var microseconds = 500_000
        for change in changes {
            if change.tick > tick { break }
            elapsed += Double(change.tick - previousTick) * Double(microseconds)
                / Double(ticksPerQuarter) / 1_000_000
            previousTick = change.tick
            microseconds = change.microsecondsPerQuarter
        }
        elapsed += Double(tick - previousTick) * Double(microseconds)
            / Double(ticksPerQuarter) / 1_000_000
        return elapsed
    }
}

private struct MIDIReader {
    let bytes: [UInt8]
    private(set) var offset = 0
    var remaining: Int { bytes.count - offset }

    mutating func readByte() throws -> UInt8 {
        guard remaining > 0 else { throw MIDIParseError.invalidFile }
        defer { offset += 1 }
        return bytes[offset]
    }

    mutating func read(count: Int) throws -> [UInt8] {
        guard count >= 0, count <= remaining else { throw MIDIParseError.invalidFile }
        defer { offset += count }
        return Array(bytes[offset..<(offset + count)])
    }

    mutating func skip(count: Int) throws {
        guard count >= 0, count <= remaining else { throw MIDIParseError.invalidFile }
        offset += count
    }

    mutating func readUInt16() throws -> UInt16 {
        let high = UInt16(try readByte())
        let low = UInt16(try readByte())
        return high << 8 | low
    }

    mutating func readUInt32() throws -> Int {
        var value = 0
        for _ in 0..<4 { value = value << 8 | Int(try readByte()) }
        return value
    }

    mutating func readVariableLength() throws -> Int {
        var value = 0
        for _ in 0..<4 {
            let byte = try readByte()
            value = value << 7 | Int(byte & 0x7F)
            if byte & 0x80 == 0 { return value }
        }
        throw MIDIParseError.invalidFile
    }
}
