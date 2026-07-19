import CoreHaptics
import UIKit
import AudioToolbox

// MARK: - CoreHaptics patterns for block cues

@MainActor
final class HapticEngine {
    static let shared = HapticEngine()

    private var engine: CHHapticEngine?

    private init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        engine?.isAutoShutdownEnabled = true

        // Restart the engine whenever the system stops or resets it (e.g. after
        // an interruption or auto-shutdown between cues from the lock screen).
        // Use the async completion-handler form — the synchronous start() can
        // fail silently when called from a background context.
        engine?.stoppedHandler = { [weak self] _ in
            self?.engine?.start(completionHandler: { _ in })
        }
        engine?.resetHandler = { [weak self] in
            self?.engine?.start(completionHandler: { _ in })
        }

        try? engine?.start()
    }

    func fire(_ cue: HapticCue) {
        switch cue {
        case .softPulse:  playSoftPulse()
        case .doubleTap:  playDoubleTap()
        case .longBuzz:   playLongBuzz()
        case .off:        break
        }
    }

    // MARK: - Patterns

    private func playSoftPulse() {
        play([
            CHHapticEvent(eventType: .hapticTransient,
                          parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                          ],
                          relativeTime: 0,
                          duration: 0.3)
        ], backgroundFallback: 1519)   // light tap — quiet, won't be heard
    }

    private func playDoubleTap() {
        play([
            CHHapticEvent(eventType: .hapticTransient,
                          parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                          ],
                          relativeTime: 0),
            CHHapticEvent(eventType: .hapticTransient,
                          parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                          ],
                          relativeTime: 0.15)
        ], backgroundFallback: 1520)   // medium tap
    }

    private func playLongBuzz() {
        play([
            CHHapticEvent(eventType: .hapticContinuous,
                          parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
                          ],
                          relativeTime: 0,
                          duration: 0.6)
        ], backgroundFallback: 1521)   // heavy tap — still gentler than kSystemSoundID_Vibrate
    }

    private func play(_ events: [CHHapticEvent], backgroundFallback: SystemSoundID = kSystemSoundID_Vibrate) {
        // CoreHaptics silently stops delivering feedback when the screen is locked —
        // it doesn't throw, it just produces nothing. Check the app state first and
        // route directly to AudioServices using a per-cue Taptic Engine sound ID
        // (1519 light / 1520 medium / 1521 heavy) — much gentler than the full
        // kSystemSoundID_Vibrate buzz and quiet enough not to be heard.
        guard UIApplication.shared.applicationState == .active else {
            AudioServicesPlaySystemSound(backgroundFallback)
            return
        }

        guard let engine else {
            AudioServicesPlaySystemSound(backgroundFallback)
            return
        }
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player  = try engine.makePlayer(with: pattern)
            try engine.start()
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            AudioServicesPlaySystemSound(backgroundFallback)
        }
    }
}
