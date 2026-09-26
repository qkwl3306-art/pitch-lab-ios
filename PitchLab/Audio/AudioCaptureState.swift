import Foundation

struct CaptureIntent {
    private var generation = 0

    mutating func begin() -> Int {
        generation += 1
        return generation
    }

    mutating func cancel() {
        generation += 1
    }

    func isCurrent(_ request: Int) -> Bool {
        generation == request
    }
}

final class AudioAnalysisGate {
    private let lock = NSLock()
    private var busy = false

    func begin() -> Bool {
        guard lock.try() else { return false }
        defer { lock.unlock() }
        guard !busy else { return false }
        busy = true
        return true
    }

    func end() {
        lock.lock()
        busy = false
        lock.unlock()
    }
}
