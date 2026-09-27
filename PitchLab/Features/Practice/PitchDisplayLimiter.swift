import Foundation

struct PitchDisplayLimiter {
    private let minimumInterval: TimeInterval = 0.2
    private(set) var lastPublishedAt: TimeInterval?

    mutating func shouldPublish(at time: TimeInterval) -> Bool {
        guard time.isFinite else { return false }
        guard let lastPublishedAt else {
            self.lastPublishedAt = time
            return true
        }
        guard time >= lastPublishedAt, time - lastPublishedAt + 1e-9 >= minimumInterval else { return false }
        self.lastPublishedAt = time
        return true
    }

    mutating func reset() {
        lastPublishedAt = nil
    }
}
