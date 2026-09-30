import XCTest
import AVFoundation
import Combine
@testable import PitchLab

final class PhrasePracticeViewModelTests: XCTestCase {
    @MainActor
    func testStopClearsPreviousPhrasePresentation() {
        let model = PhrasePracticeViewModel(microphone: TestPitchCapture())
        model.begin(score: score, phrase: phrase, transposition: 0, mode: .wholePhrase)
        model.skipCurrent()
        model.stop()
        XCTAssertNil(model.targetNoteIndex)
        XCTAssertNil(model.targetName)
        XCTAssertTrue(model.skippedNoteIndices.isEmpty)
        XCTAssertTrue(model.readings.isEmpty)
    }

    @MainActor
    func testSkippedNotesWithoutPitchEvidenceArePendingRetry() {
        let model = PhrasePracticeViewModel(microphone: TestPitchCapture())
        model.begin(score: score, phrase: phrase, transposition: 0, mode: .wholePhrase)
        model.skipCurrent()
        model.skipCurrent()
        XCTAssertEqual(model.feedback?.notes.map(\.status), [.missed, .missed])
        model.stop()
    }

    @MainActor
    func testRepeatedBeginReusesActiveCapture() {
        let capture = TestPitchCapture()
        let model = PhrasePracticeViewModel(microphone: capture)
        model.begin(score: score, phrase: phrase, transposition: 0, mode: .wholePhrase)
        let stops = capture.stopCount
        model.skipCurrent()
        model.skipCurrent()
        model.begin(score: score, phrase: phrase, transposition: 0, mode: .noteByNote)
        XCTAssertEqual(capture.startCount, 1)
        XCTAssertEqual(capture.stopCount, stops)
        XCTAssertEqual(model.mode, .noteByNote)
        model.stop()
    }

    @MainActor
    func testCentsDisplayIsThrottledWhileEverySampleIsScored() {
        let capture = TestPitchCapture()
        var time = 100.0
        let model = PhrasePracticeViewModel(microphone: capture, now: { time })
        model.begin(score: score, phrase: phrase, transposition: 0, mode: .wholePhrase)
        var publications = 0
        let subscription = model.$targetCents.dropFirst().sink { _ in publications += 1 }
        for index in 0..<20 {
            time = 100 + Double(index) * 0.01
            capture.pitch.send(NoteMath.frequency(midi: 61))
        }
        XCTAssertEqual(publications, 1)
        time = 101
        capture.pitch.send(NoteMath.frequency(midi: 60))
        time = 101.26
        capture.pitch.send(NoteMath.frequency(midi: 60))
        XCTAssertEqual(model.targetNoteIndex, 1)
        subscription.cancel()
        model.stop()
    }

    @MainActor
    func testRestartResetsTraceClock() {
        let capture = TestPitchCapture()
        var time = 100.0
        let model = PhrasePracticeViewModel(microphone: capture, now: { time })
        model.begin(score: score, phrase: phrase, transposition: 0, mode: .wholePhrase)
        time = 160
        capture.pitch.send(NoteMath.frequency(midi: 61))
        model.restart()
        time = 160.2
        capture.pitch.send(NoteMath.frequency(midi: 61))
        XCTAssertEqual(model.readings.last?.time ?? -1, 0.2, accuracy: 0.0001)
        XCTAssertEqual(capture.startCount, 1)
        model.stop()
    }

    private var score: VocalScore {
        VocalScore(notes: [60, 62].enumerated().map {
            VocalNote(onset: Double($0.offset), duration: 1, midi: $0.element, lyric: nil)
        }, title: "Test")
    }
    private var phrase: VocalPhrase {
        VocalPhrase(id: 0, noteRange: 0..<2, start: 0, end: 2, text: "Test")
    }
}

@MainActor
final class TestPitchCapture: PracticePitchCapture {
    let pitch = PassthroughSubject<Double?, Never>()
    private let statuses = CurrentValueSubject<MicrophonePitchService.Status, Never>(.idle)
    var status: MicrophonePitchService.Status { statuses.value }
    var statusPublisher: AnyPublisher<MicrophonePitchService.Status, Never> { statuses.eraseToAnyPublisher() }
    var pitchPublisher: AnyPublisher<Double?, Never> { pitch.eraseToAnyPublisher() }
    private(set) var startCount = 0
    private(set) var stopCount = 0
    func start(mode: AVAudioSession.Mode?) {
        startCount += 1
        statuses.send(.listening)
    }
    func stop() {
        stopCount += 1
        statuses.send(.idle)
    }
}
