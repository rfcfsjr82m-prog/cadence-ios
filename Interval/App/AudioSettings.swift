import Foundation
import AVFoundation
import UIKit

// MARK: - Persisted audio preferences

@Observable
final class AudioSettings: @unchecked Sendable {
    static let shared = AudioSettings()

    var volume: Double {
        didSet { UserDefaults.standard.set(volume, forKey: "audioVolume") }
    }

    var duckOthers: Bool {
        didSet {
            UserDefaults.standard.set(duckOthers, forKey: "audioDuck")
            applyAudioSession()
        }
    }

    private init() {
        let saved = UserDefaults.standard.object(forKey: "audioVolume") as? Double
        volume = saved ?? 1.0
        let savedDuck = UserDefaults.standard.object(forKey: "audioDuck") as? Bool
        duckOthers = savedDuck ?? true  // default ON so cues are always audible over music
        setupInterruptionHandling()
    }

    // MARK: - Audio session

    func applyAudioSession() {
        let options: AVAudioSession.CategoryOptions = duckOthers
            ? [.duckOthers]
            : [.mixWithOthers]
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: options)

        // If another app has exclusive audio, setActive may fail.
        // Retry once after 0.5 s — by then the other app is usually done.
        do {
            try session.setActive(true)
        } catch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                try? session.setActive(true)
            }
        }
    }

    // MARK: - Interruption handling
    //
    // When a phone call, Siri, or another app interrupts our audio session, iOS
    // deactivates it.  Once the interruption ends we must re-activate so that
    // subsequent cues keep playing from the lock screen / background.

    private func setupInterruptionHandling() {
        // Re-activate after phone calls, Siri, or other audio interruptions.
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard
                let userInfo = notification.userInfo,
                let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                let type = AVAudioSession.InterruptionType(rawValue: typeValue)
            else { return }

            if type == .ended {
                self?.applyAudioSession()
            }
        }

        // Re-activate when the app moves to background.
        // iOS can deactivate the session at the exact moment of the scene transition;
        // calling setActive(true) here ensures cues keep firing from the lock screen.
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyAudioSession()
        }

        // Route changes (AirPods connect/disconnect, headphones, etc.)
        // can cause a brief session gap — re-activate to be safe.
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyAudioSession()
        }

        // Media server can reset after a crash — re-apply to be safe.
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyAudioSession()
        }
    }
}
