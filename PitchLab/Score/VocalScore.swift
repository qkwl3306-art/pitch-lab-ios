import Foundation

struct VocalNote: Codable, Equatable {
    let onset: Double
    let duration: Double
    let midi: Int
    let lyric: String?
    let beatOnset: Double?
    let beatDuration: Double?

    init(onset: Double, duration: Double, midi: Int, lyric: String?,
         beatOnset: Double? = nil, beatDuration: Double? = nil) {
        self.onset = onset
        self.duration = duration
        self.midi = midi
        self.lyric = lyric
        self.beatOnset = beatOnset
        self.beatDuration = beatDuration
    }
}

struct VocalScore: Codable, Equatable {
    let notes: [VocalNote]
    let title: String
    let beatDuration: Double

    init(notes: [VocalNote], title: String, beatDuration: Double = 0.5) {
        self.notes = notes
        self.title = title
        self.beatDuration = beatDuration
    }
}
