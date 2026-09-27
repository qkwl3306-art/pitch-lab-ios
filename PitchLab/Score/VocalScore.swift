import Foundation

struct VocalNote: Codable, Equatable {
    let onset: Double
    let duration: Double
    let midi: Int
    let lyric: String?
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
