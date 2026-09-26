import Foundation

/// The singer's comfortable, sustainable MIDI-note range, including both ends.
struct VocalRange: Codable, Equatable {
    let low: Int
    let high: Int
}
