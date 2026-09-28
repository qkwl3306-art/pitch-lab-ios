import Foundation

enum SelfPacedPracticeMode: String, CaseIterable, Identifiable {
    case noteByNote
    case progressive
    case wholePhrase

    var id: String { rawValue }

    var title: String {
        switch self {
        case .noteByNote: "逐音练习"
        case .progressive: "递进练句"
        case .wholePhrase: "整句跟唱"
        }
    }
}

struct SelfPacedPitchUpdate: Equatable {
    let cents: Double?
    let didPass: Bool
    let didExpandStage: Bool
    let didCompletePhrase: Bool
}

struct SelfPacedPracticeSession {
    let noteRange: Range<Int>
    let mode: SelfPacedPracticeMode

    private(set) var currentNoteIndex: Int?
    private(set) var progressiveEndIndex: Int?
    private(set) var passedNoteIndices: Set<Int> = []
    private(set) var skippedNoteIndices: Set<Int> = []

    private var stablePitchSince: TimeInterval?
    private var lastObservationAt: TimeInterval?
    private var currentNotePassed = false
    private var lastPassedTargetMIDI: Int?
    private var observedPitchBreakSinceLastPass = true

    private let accuracyToleranceCents = 50.0
    private let stablePitchDuration = 0.25

    init(noteRange: Range<Int>, mode: SelfPacedPracticeMode) {
        self.noteRange = noteRange
        self.mode = mode
        currentNoteIndex = noteRange.isEmpty ? nil : noteRange.lowerBound
        progressiveEndIndex = mode == .progressive && !noteRange.isEmpty ? noteRange.lowerBound : nil
    }

    var isComplete: Bool { currentNoteIndex == nil }

    var unresolvedNoteIndices: Set<Int> {
        Set(noteRange).subtracting(passedNoteIndices)
    }

    mutating func observe(frequency: Double?, targetMIDI: Int, at time: TimeInterval) -> SelfPacedPitchUpdate {
        guard let currentNoteIndex, time.isFinite else { return emptyUpdate }

        if let lastObservationAt, time < lastObservationAt {
            stablePitchSince = nil
        }
        lastObservationAt = time

        let cents: Double?
        if let frequency, frequency.isFinite, frequency > 0 {
            let measuredCents = NoteMath.cents(frequency: frequency, midi: targetMIDI)
            cents = measuredCents.isFinite ? measuredCents : nil
        } else {
            cents = nil
        }

        guard let cents, abs(cents) <= accuracyToleranceCents else {
            stablePitchSince = nil
            observedPitchBreakSinceLastPass = true
            return SelfPacedPitchUpdate(cents: cents, didPass: false,
                                        didExpandStage: false, didCompletePhrase: false)
        }

        if currentNotePassed {
            return SelfPacedPitchUpdate(cents: cents, didPass: false,
                                        didExpandStage: false, didCompletePhrase: false)
        }

        if targetMIDI == lastPassedTargetMIDI, !observedPitchBreakSinceLastPass {
            stablePitchSince = nil
            return SelfPacedPitchUpdate(cents: cents, didPass: false,
                                        didExpandStage: false, didCompletePhrase: false)
        }

        if stablePitchSince == nil { stablePitchSince = time }
        guard let stablePitchSince, time - stablePitchSince >= stablePitchDuration else {
            return SelfPacedPitchUpdate(cents: cents, didPass: false,
                                        didExpandStage: false, didCompletePhrase: false)
        }

        currentNotePassed = true
        passedNoteIndices.insert(currentNoteIndex)
        skippedNoteIndices.remove(currentNoteIndex)
        lastPassedTargetMIDI = targetMIDI
        observedPitchBreakSinceLastPass = false
        self.stablePitchSince = nil

        var didExpandStage = false
        switch mode {
        case .noteByNote:
            break
        case .progressive:
            if currentNoteIndex < (progressiveEndIndex ?? currentNoteIndex) {
                moveTarget(to: currentNoteIndex + 1)
            } else if let progressiveEndIndex {
                let stageRange = noteRange.lowerBound...(progressiveEndIndex)
                let stagePassed = stageRange.allSatisfy(passedNoteIndices.contains)
                if stagePassed, progressiveEndIndex + 1 < noteRange.upperBound {
                    let newEnd = progressiveEndIndex + 1
                    self.progressiveEndIndex = newEnd
                    for index in noteRange.lowerBound...newEnd {
                        passedNoteIndices.remove(index)
                    }
                    moveTarget(to: noteRange.lowerBound)
                    didExpandStage = true
                } else if stagePassed {
                    self.currentNoteIndex = nil
                } else {
                    moveTarget(to: stageRange.first(where: { !passedNoteIndices.contains($0) }) ?? progressiveEndIndex)
                }
            }
        case .wholePhrase:
            if currentNoteIndex + 1 < noteRange.upperBound {
                moveTarget(to: currentNoteIndex + 1)
            } else {
                self.currentNoteIndex = nil
            }
        }

        return SelfPacedPitchUpdate(cents: cents, didPass: true,
                                    didExpandStage: didExpandStage, didCompletePhrase: isComplete)
    }

    mutating func advance() {
        guard let currentNoteIndex else { return }
        if passedNoteIndices.contains(currentNoteIndex) {
            moveToNextAfterManualAdvance(from: currentNoteIndex)
        } else {
            skippedNoteIndices.insert(currentNoteIndex)
            moveToNextAfterManualAdvance(from: currentNoteIndex)
        }
        if self.currentNoteIndex == nil, mode == .progressive,
           passedNoteIndices.count == noteRange.count {
            passedNoteIndices = []
            progressiveEndIndex = noteRange.isEmpty ? nil : noteRange.lowerBound
            currentNoteIndex = noteRange.isEmpty ? nil : noteRange.lowerBound
            currentNotePassed = false
        }
    }

    mutating func skipCurrent() {
        advance()
    }

    mutating func retry(noteIndex: Int) {
        guard noteRange.contains(noteIndex) else { return }
        passedNoteIndices.remove(noteIndex)
        skippedNoteIndices.remove(noteIndex)
        lastPassedTargetMIDI = nil
        observedPitchBreakSinceLastPass = true
        if mode == .progressive {
            progressiveEndIndex = max(progressiveEndIndex ?? noteIndex, noteIndex)
        }
        moveTarget(to: noteIndex)
    }

    mutating func restart() {
        passedNoteIndices = []
        skippedNoteIndices = []
        progressiveEndIndex = mode == .progressive && !noteRange.isEmpty ? noteRange.lowerBound : nil
        moveTarget(to: noteRange.isEmpty ? nil : noteRange.lowerBound)
        lastPassedTargetMIDI = nil
        observedPitchBreakSinceLastPass = true
    }

    private var emptyUpdate: SelfPacedPitchUpdate {
        SelfPacedPitchUpdate(cents: nil, didPass: false, didExpandStage: false, didCompletePhrase: isComplete)
    }

    private mutating func moveToNextAfterManualAdvance(from index: Int) {
        stablePitchSince = nil
        if mode == .progressive {
            guard let progressiveEndIndex else {
                moveTarget(to: nil)
                return
            }
            if index < progressiveEndIndex {
                moveTarget(to: index + 1)
            } else {
                let stageRange = noteRange.lowerBound...progressiveEndIndex
                moveTarget(to: stageRange.first(where: { !passedNoteIndices.contains($0) }))
            }
            return
        }
        moveTarget(to: index + 1 < noteRange.upperBound ? index + 1 : nil)
    }

    private mutating func moveTarget(to index: Int?) {
        currentNoteIndex = index
        stablePitchSince = nil
        lastObservationAt = nil
        currentNotePassed = index.map(passedNoteIndices.contains) ?? false
    }
}
