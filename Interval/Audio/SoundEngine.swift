import AVFoundation
import UIKit

// MARK: - Plays pre-recorded WAV/MP3 cue files

@MainActor
final class SoundEngine: ObservableObject {
    static let shared = SoundEngine()

    private var players: [SoundCue: AVAudioPlayer] = [:]
    private var keepAlivePlayer: AVAudioPlayer?

    private init() {
        AudioSettings.shared.applyAudioSession()
        observeBackgroundTransitions()
    }

    // MARK: - Public

    func preload(cues: Set<SoundCue>) {
        for cue in cues {
            guard let filename = cue.filename,
                  let url = Bundle.main.url(forResource: filename,
                                            withExtension: cue.fileExtension) else { continue }
            let player = try? AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            players[cue] = player
        }
    }

    func preloadAll() {
        preload(cues: Set(SoundCue.allCases))
    }

    /// Plays a cue.  Silently no-ops for `.silent`.
    func play(_ cue: SoundCue) {
        guard cue != .silent else { return }

        // Ensure the session is active before every play.
        // This re-activates it after phone calls, route changes, or the
        // brief window when iOS deactivates it as the app backgrounds.
        AudioSettings.shared.applyAudioSession()

        guard let player = players[cue] else { return }
        player.volume      = Float(AudioSettings.shared.volume)
        player.currentTime = 0

        // Always re-prepare before playing.
        // AVAudioPlayer can go stale after session interruptions; prepareToPlay()
        // primes the audio hardware and fixes "silent cue" bugs from the lock screen.
        player.prepareToPlay()
        player.play()
    }

    /// Recreates all loaded players — call after an interruption to guarantee
    /// freshly-allocated AVAudioPlayer instances that aren't in a bad state.
    func reloadPlayers() {
        let cues = Set(players.keys)
        players.removeAll()
        preload(cues: cues)
    }

    func stopAll() {
        players.values.forEach { $0.stop() }
    }

    // MARK: - Silent keepalive

    /// Starts a silent looping audio player to hold the AVAudioSession active
    /// while the app is backgrounded between cues.  iOS suspends background audio
    /// the moment nothing is playing; this zero-volume loop prevents that gap.
    func startKeepAlive() {
        guard keepAlivePlayer == nil else { return }
        let data = Self.silentWAVData()
        keepAlivePlayer = try? AVAudioPlayer(data: data,
                                             fileTypeHint: AVFileType.wav.rawValue)
        keepAlivePlayer?.numberOfLoops = -1   // loop indefinitely
        keepAlivePlayer?.volume        = 0
        keepAlivePlayer?.prepareToPlay()
        keepAlivePlayer?.play()
    }

    func stopKeepAlive() {
        keepAlivePlayer?.stop()
        keepAlivePlayer = nil
    }

    /// Builds the smallest valid PCM WAV blob in memory (44-byte header + 1 silent sample).
    private static func silentWAVData() -> Data {
        var d = Data()

        func append<T: FixedWidthInteger>(_ v: T) {
            var le = v.littleEndian
            d.append(contentsOf: withUnsafeBytes(of: &le) { Array($0) })
        }

        let sampleRate:    UInt32 = 44100
        let numChannels:   UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate               = sampleRate * UInt32(numChannels) * UInt32(bitsPerSample) / 8
        let blockAlign:    UInt16  = numChannels * bitsPerSample / 8
        let dataSize:      UInt32  = 2          // one 16-bit silent sample

        // RIFF header
        d.append(contentsOf: "RIFF".utf8)
        append(UInt32(36 + dataSize))           // chunk size
        d.append(contentsOf: "WAVE".utf8)

        // fmt sub-chunk
        d.append(contentsOf: "fmt ".utf8)
        append(UInt32(16))                      // sub-chunk size (PCM)
        append(UInt16(1))                       // audio format = PCM
        append(numChannels)
        append(sampleRate)
        append(byteRate)
        append(blockAlign)
        append(bitsPerSample)

        // data sub-chunk
        d.append(contentsOf: "data".utf8)
        append(dataSize)
        append(Int16(0))                        // one silent sample

        return d
    }

    // MARK: - Background handling

    private func observeBackgroundTransitions() {
        // When the app moves to background, re-prepare all loaded players so they are
        // in an optimal state for the next cue that fires from the lock screen.
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.players.values.forEach { $0.prepareToPlay() }
            }
        }

        // After ANY audio-session interruption ends, recreate players from scratch
        // so we are never stuck with a player in an error/stopped state.
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard
                let userInfo = notification.userInfo,
                let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                let type = AVAudioSession.InterruptionType(rawValue: typeValue),
                type == .ended
            else { return }

            Task { @MainActor [weak self] in
                self?.reloadPlayers()
            }
        }
    }
}
