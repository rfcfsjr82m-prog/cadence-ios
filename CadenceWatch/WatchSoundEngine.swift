import AVFoundation

@MainActor
final class WatchSoundEngine {
    private var player: AVAudioPlayer?
    private let synthesizer = AVSpeechSynthesizer()

    func play(_ cue: SoundCue) {
        guard let filename = cue.filename else { return }
        guard let url = Bundle.main.url(forResource: filename, withExtension: cue.fileExtension) else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }

    func playAnnouncement(_ cue: AnnouncementCue) {
        switch cue {
        case .none: break
        case .sound(let soundCue): play(soundCue)
        case .voice(let gender):
            // Try pre-recorded MP3 first; fall back to TTS
            let announcement = VoiceAnnouncement.start(gender)
            if let url = Bundle.main.url(forResource: announcement.filename, withExtension: "mp3") {
                try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try? AVAudioSession.sharedInstance().setActive(true)
                player = try? AVAudioPlayer(contentsOf: url)
                player?.play()
            } else {
                speakTTS(gender: gender, text: announcement.spokenText)
            }
        }
    }

    func playFinishAnnouncement(_ cue: AnnouncementCue) {
        switch cue {
        case .none: break
        case .sound(let soundCue): play(soundCue)
        case .voice(let gender):
            let announcement = VoiceAnnouncement.finish(gender)
            if let url = Bundle.main.url(forResource: announcement.filename, withExtension: "mp3") {
                try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try? AVAudioSession.sharedInstance().setActive(true)
                player = try? AVAudioPlayer(contentsOf: url)
                player?.play()
            } else {
                speakTTS(gender: gender, text: announcement.spokenText)
            }
        }
    }

    private func speakTTS(gender: VoiceGender, text: String) {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = bestVoice(for: gender)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.90
        synthesizer.speak(utterance)
    }

    private func bestVoice(for gender: VoiceGender) -> AVSpeechSynthesisVoice? {
        let targetGender: AVSpeechSynthesisVoiceGender = gender == .female ? .female : .male
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") && $0.gender == targetGender }
        for q in [AVSpeechSynthesisVoiceQuality.enhanced, .premium, .default] {
            if let v = voices.first(where: { $0.quality == q }) { return v }
        }
        return AVSpeechSynthesisVoice(language: "en-US")
    }
}
