import Foundation

struct RollingPitchTrace {
    static let duration = 8.0
    let end: Double
    var start: Double { end - Self.duration }

    init(latestTime: Double) { end = max(Self.duration, latestTime) }

    func position(at time: Double) -> Double? {
        guard time.isFinite, time >= start, time <= end else { return nil }
        return (time - start) / Self.duration
    }

    static func midi(frequency: Double) -> Double? {
        guard frequency.isFinite, frequency > 0 else { return nil }
        let value = 69 + 12 * log2(frequency / 440)
        return value.isFinite ? value : nil
    }
}
