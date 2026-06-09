import AVFoundation

@MainActor
final class WatchSoundEngine {
    private var player: AVAudioPlayer?

    func play(_ cue: SoundCue) {
        guard let filename = cue.filename else { return }
        guard let url = Bundle.main.url(forResource: filename, withExtension: cue.fileExtension) else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }
}
