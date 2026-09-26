import Combine
import Foundation

@MainActor
final class QuizViewModel: ObservableObject {
    @Published private(set) var session = QuizSession.randomRound()
    private let player = TonePlayer()
    private var playbackTask: Task<Void, Never>?

    func playCurrent() {
        guard let note = session.currentNote else { return }
        playbackTask?.cancel()
        player.stopAll()
        player.noteOn(midi: note)
        playbackTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            self?.player.noteOff(midi: note)
        }
    }

    func answer(_ pitchClass: Int) {
        session.answer(pitchClass: pitchClass)
        playbackTask?.cancel()
        player.stopAll()
        if !session.isFinished {
            playbackTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                self?.playCurrent()
            }
        }
    }

    func restart() {
        playbackTask?.cancel()
        player.stopAll()
        session = .randomRound()
        playCurrent()
    }

    func stop() {
        playbackTask?.cancel()
        player.stopAll()
    }
}
