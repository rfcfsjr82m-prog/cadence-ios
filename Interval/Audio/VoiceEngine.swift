import AVFoundation

// MARK: - Plays voice announcements for session start and finish.
//
// ┌─────────────────────────────────────────────────────────────────┐
// │  TEST FLAG — change ONE line to revert to pre-recorded MP3s:   │
// │      private let useSpeechSynthesizer = false                   │
// └─────────────────────────────────────────────────────────────────┘

@MainActor
final class VoiceEngine {
    static let shared = VoiceEngine()

    // ── Revert flag ────────────────────────────────────────────────
    // `true`  → AVSpeechSynthesizer (on-device TTS, no audio files needed)
    // `false` → original pre-recorded MP3 files (Voice_Female_Start.mp3 etc.)
    private let useSpeechSynthesizer = false
    // ──────────────────────────────────────────────────────────────

    // Pre-recorded path
    private var filePlayer: AVAudioPlayer?

    // TTS path
    private let synthesizer = AVSpeechSynthesizer()

    private init() {}

    // MARK: - Public API

    /// Plays a session-level announcement (start / finish).
    /// Routes to TTS or pre-recorded file depending on `useSpeechSynthesizer`.
    func play(_ announcement: VoiceAnnouncement) {
        if useSpeechSynthesizer {
            speakTTS(announcement)
        } else {
            playFile(announcement)
        }
    }

    /// Speaks a block label name via TTS. Always uses AVSpeechSynthesizer
    /// regardless of the `useSpeechSynthesizer` flag — this is a separate
    /// feature from the start/finish announcements.
    func speakLabel(_ text: String, gender: VoiceGender) {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        // Re-apply session so AVSpeechSynthesizer respects our duck-others setting.
        AudioSettings.shared.applyAudioSession()
        let utterance        = AVSpeechUtterance(string: text)
        utterance.voice      = bestVoice(for: gender)
        utterance.rate       = AVSpeechUtteranceDefaultSpeechRate * 0.90
        utterance.pitchMultiplier = 1.0
        utterance.volume     = Float(AudioSettings.shared.volume)
        synthesizer.speak(utterance)
    }

    // MARK: - AVSpeechSynthesizer path

    private func speakTTS(_ announcement: VoiceAnnouncement) {
        // Cancel any in-progress utterance so back-to-back calls don't queue up.
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: announcement.spokenText)
        utterance.voice           = bestVoice(for: announcement.gender)
        utterance.rate            = AVSpeechUtteranceDefaultSpeechRate * 0.90  // calm pace
        utterance.pitchMultiplier = 1.0
        utterance.volume          = Float(AudioSettings.shared.volume)

        synthesizer.speak(utterance)
    }

    /// Finds the best available English voice matching the requested gender.
    /// Falls back to the system default en-US voice if none match.
    private func bestVoice(for gender: VoiceGender) -> AVSpeechSynthesisVoice? {
        let targetGender: AVSpeechSynthesisVoiceGender = gender == .female ? .female : .male

        // Prefer enhanced/premium voices, then compact, then anything.
        let englishVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") && $0.gender == targetGender }

        let quality: [AVSpeechSynthesisVoiceQuality] = [.enhanced, .premium, .default]
        for q in quality {
            if let v = englishVoices.first(where: { $0.quality == q }) { return v }
        }

        // Last resort: system default (typically female en-US)
        return AVSpeechSynthesisVoice(language: "en-US")
    }

    // MARK: - Pre-recorded MP3 path (original — preserved for easy revert)

    private func playFile(_ announcement: VoiceAnnouncement) {
        guard let url = Bundle.main.url(forResource: announcement.filename,
                                        withExtension: "mp3") else { return }
        AudioSettings.shared.applyAudioSession()
        filePlayer = try? AVAudioPlayer(contentsOf: url)
        filePlayer?.volume = Float(AudioSettings.shared.volume)
        filePlayer?.prepareToPlay()
        filePlayer?.play()
    }
}
