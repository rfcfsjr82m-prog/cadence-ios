import AVFoundation

// MARK: - Shared synthesised beep used by the opening countdown
//         and the round prep signal.

@MainActor
final class BeepPlayer {
    static let shared = BeepPlayer()

    private var player: AVAudioPlayer?

    private init() { prepare() }

    func play() {
        player?.currentTime = 0
        player?.play()
    }

    // MARK: - Synthesis (660 Hz soft beep, 220 ms)

    private func prepare() {
        let sampleRate: Double = 44100
        let duration: Double   = 0.22
        let freq: Double       = 660
        let frameCount = Int(sampleRate * duration)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: AVAudioFrameCount(frameCount)) else { return }
        buffer.frameLength = AVAudioFrameCount(frameCount)
        let data = buffer.floatChannelData![0]
        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            let envelope = max(0, 1 - t / duration)
            data[i] = Float(sin(2 * Double.pi * freq * t) * 0.25 * envelope)
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("shared_beep.wav")
        if let file = try? AVAudioFile(forWriting: url, settings: format.settings) {
            try? file.write(from: buffer)
        }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
    }
}
