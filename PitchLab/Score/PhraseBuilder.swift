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
        var boundedStarts = [0]
        for segment in 0..<(starts.count - 1) {
            var lower = starts[segment]
            let upper = starts[segment + 1]
            while upper - lower > 16 {
                let candidates = ((lower + 12)...(lower + 16)).filter { index in
                    guard let beat = notes[index].beatOnset else { return false }
                    return abs(beat.truncatingRemainder(dividingBy: 4)) < 0.1
                }
                let boundary = candidates.last ?? lower + 16
                boundedStarts.append(boundary)
                lower = boundary
            }
            boundedStarts.append(upper)
        }
        return (0..<(boundedStarts.count - 1)).map { phraseIndex in
            let lower = boundedStarts[phraseIndex]
            let upper = boundedStarts[phraseIndex + 1]
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

    static func moveBoundary(after index: Int, by delta: Int,
                             in phrases: [VocalPhrase], score: VocalScore) -> [VocalPhrase]? {
        guard phrases.indices.contains(index), phrases.indices.contains(index + 1), delta != 0 else { return nil }
        var result = phrases
        let left = result[index]
        let right = result[index + 1]
        let newBoundary = left.noteRange.upperBound + delta
        guard newBoundary > left.noteRange.lowerBound,
              newBoundary < right.noteRange.upperBound,
              score.notes.indices.contains(newBoundary),
              score.notes.indices.contains(newBoundary - 1) else { return nil }
        result[index].noteRange = left.noteRange.lowerBound..<newBoundary
        result[index].end = score.notes[newBoundary - 1].onset + score.notes[newBoundary - 1].duration
        result[index + 1].noteRange = newBoundary..<right.noteRange.upperBound
        result[index + 1].start = score.notes[newBoundary].onset
        return result
    }
}
