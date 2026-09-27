import Foundation

struct VocalPhrase: Codable, Equatable, Identifiable {
    let id: Int
    var noteRange: Range<Int>
    var start: Double
    var end: Double
    var text: String
}

enum PhraseBuilder {
    static func make(score: VocalScore) -> [VocalPhrase] {
        guard !score.notes.isEmpty else { return [] }
        let notes = score.notes
        let minimumGap = max(0.1, score.beatDuration * 2)
        var starts = [0]
        for index in 1..<notes.count {
            let previous = notes[index - 1]
            let current = notes[index]
            let shouldSplit: Bool
            if let beatStart = current.beatOnset,
               let previousBeatStart = previous.beatOnset,
               let previousBeatDuration = previous.beatDuration {
                shouldSplit = beatStart - previousBeatStart - previousBeatDuration >= 2
            } else {
                shouldSplit = current.onset - previous.onset - previous.duration >= minimumGap
            }
            if shouldSplit {
                starts.append(index)
            }
        }
        starts.append(notes.count)
        return (0..<(starts.count - 1)).map { phraseIndex in
            let lower = starts[phraseIndex]
            let upper = starts[phraseIndex + 1]
            return VocalPhrase(
                id: phraseIndex,
                noteRange: lower..<upper,
                start: notes[lower].onset,
                end: notes[upper - 1].onset + notes[upper - 1].duration,
                text: "第 \(phraseIndex + 1) 句"
            )
        }
    }

    static func attachLyrics(_ lines: [LyricLine], to phrases: [VocalPhrase]) -> [VocalPhrase] {
        guard !phrases.isEmpty, !lines.isEmpty else { return phrases }
        var result = phrases
        if lines.allSatisfy({ $0.time == nil }) {
            for (index, line) in lines.prefix(result.count).enumerated() {
                result[index].text = line.text
            }
            return result
        }
        for line in lines {
            guard let time = line.time else { continue }
            let nearest = result.indices.min { abs(result[$0].start - time) < abs(result[$1].start - time) }
            if let nearest {
                if result[nearest].text == phrases[nearest].text {
                    result[nearest].text = line.text
                } else {
                    result[nearest].text += " " + line.text
                }
            }
        }
        return result
    }
}
