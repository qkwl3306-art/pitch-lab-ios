import Foundation

enum PracticeAccess: Equatable {
    case locked, trial(until: Date), unlocked

    static func evaluate(trialStarted: Date?, purchased: Bool, now: Date) -> Self {
        if purchased { return .unlocked }
        guard let trialStarted, trialStarted <= now else { return .locked }
        let end = trialStarted.addingTimeInterval(7 * 24 * 60 * 60)
        return now < end ? .trial(until: end) : .locked
    }

    var allowsPractice: Bool { self != .locked }
}
