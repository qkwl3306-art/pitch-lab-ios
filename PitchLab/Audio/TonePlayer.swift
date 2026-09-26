import AVFoundation
import Foundation

@MainActor
final class TonePlayer {
    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var players: [Int: AVAudioPlayerNode] = [:]

    func noteOn(midi: Int) {
        guard players[midi] == nil else { return }
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        do {
            if !engine.isRunning {
                if AVAudioSession.sharedInstance().category != .playAndRecord {
                    try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
                }
                try AVAudioSession.sharedInstance().setActive(true)
                try engine.start()
            }
            let buffer = makeBuffer(midi: midi)
            player.volume = 0.22
            player.scheduleBuffer(buffer, at: nil, options: .loops)
            player.play()
            players[midi] = player
        } catch {
            engine.detach(player)
            // Audio route errors leave the key silent; the next key retries activation.
        }
    }

    func noteOff(midi: Int) {
        guard let player = players.removeValue(forKey: midi) else { return }
        player.stop()
        engine.detach(player)
    }

    func stopAll() {
        for midi in Array(players.keys) { noteOff(midi: midi) }
        engine.stop()
    }

    private func makeBuffer(midi: Int) -> AVAudioPCMBuffer {
        let frequency = NoteMath.frequency(midi: midi)
        let cycles = 128.0
        let frames = Int((cycles * format.sampleRate / frequency).rounded())
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
        buffer.frameLength = AVAudioFrameCount(frames)
        let samples = buffer.floatChannelData![0]
        for index in 0..<frames {
            let phase = 2 * Double.pi * cycles * Double(index) / Double(frames)
            samples[index] = Float(sin(phase))
        }
        return buffer
    }
}
