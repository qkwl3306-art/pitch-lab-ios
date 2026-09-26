import Foundation

enum PitchDetector {
    static func detect(samples: [Float], sampleRate: Double) -> Double? {
        guard sampleRate > 0, samples.count >= 1_024 else { return nil }
        let count = min(samples.count, 4_096)
        let data = Array(samples.suffix(count)).map(Double.init)
        let mean = data.reduce(0, +) / Double(count)
        let centered = data.map { $0 - mean }
        let energy = centered.reduce(0) { $0 + $1 * $1 } / Double(count)
        guard energy > 0.000_01 else { return nil }

        let minLag = max(2, Int(sampleRate / 1_000))
        let maxLag = min(count / 2, Int(sampleRate / 80))
        guard minLag + 2 < maxLag else { return nil }
        var correlations = Array(repeating: 0.0, count: maxLag + 1)
        for lag in minLag...maxLag {
            var dot = 0.0
            var left = 0.0
            var right = 0.0
            for i in 0..<(count - lag) {
                let a = centered[i]
                let b = centered[i + lag]
                dot += a * b
                left += a * a
                right += b * b
            }
            correlations[lag] = dot / sqrt(max(left * right, 0.000_000_1))
        }
        for lag in (minLag + 1)..<maxLag {
            let peak = correlations[lag]
            if peak > 0.87, peak > correlations[lag - 1], peak >= correlations[lag + 1] {
                let a = correlations[lag - 1]
                let b = peak
                let c = correlations[lag + 1]
                let divisor = a - 2 * b + c
                let offset = abs(divisor) > 0.000_001 ? 0.5 * (a - c) / divisor : 0
                return sampleRate / (Double(lag) + offset)
            }
        }
        return nil
    }
}
