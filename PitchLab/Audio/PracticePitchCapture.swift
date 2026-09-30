import AVFoundation
import Combine

@MainActor
protocol PracticePitchCapture: AnyObject {
    var status: MicrophonePitchService.Status { get }
    var statusPublisher: AnyPublisher<MicrophonePitchService.Status, Never> { get }
    var pitchPublisher: AnyPublisher<Double?, Never> { get }
    func start(mode: AVAudioSession.Mode?)
    func stop()
}

extension MicrophonePitchService: PracticePitchCapture {
    var statusPublisher: AnyPublisher<Status, Never> { $status.eraseToAnyPublisher() }
    var pitchPublisher: AnyPublisher<Double?, Never> { $pitchHz.eraseToAnyPublisher() }
}

#if DEBUG
/// UI tests drive controls without requiring a physical simulator microphone.
@MainActor
final class UITestPracticeCapture: PracticePitchCapture {
    private let statuses = CurrentValueSubject<MicrophonePitchService.Status, Never>(.idle)
    var status: MicrophonePitchService.Status { statuses.value }
    var statusPublisher: AnyPublisher<MicrophonePitchService.Status, Never> { statuses.eraseToAnyPublisher() }
    var pitchPublisher: AnyPublisher<Double?, Never> { Empty().eraseToAnyPublisher() }
    func start(mode: AVAudioSession.Mode?) { statuses.send(.listening) }
    func stop() { statuses.send(.idle) }
}
#endif
