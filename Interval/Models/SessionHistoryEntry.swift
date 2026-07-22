import Foundation
import SwiftData

// MARK: - Session history

// One entry is recorded every time a session ends (natural completion or manual stop)
// and the user taps "Back to Library" from the session-done overlay.
// The full config is stored as JSON so deleted timers can still be shown and restored.

@Model
final class SessionHistoryEntry {
    // No `@Attribute(.unique)` and all properties defaulted — required for the
    // SwiftData + CloudKit mirrored store. Each entry is created with a fresh
    // UUID, so history rows never collide across devices.
    var id: UUID = UUID()
    var configID: UUID = UUID()     // original timer ID — used to detect if it was deleted
    var configName: String = ""     // cached for display without decoding
    var payload: Data = Data()      // full TimerConfig JSON
    var practisedAt: Date = Date()
    var wasCompleted: Bool = false  // true = natural end, false = manually stopped
    var elapsedSeconds: Int = 0
    var totalSeconds: Int = 0

    init(config: TimerConfig, wasCompleted: Bool, elapsedSeconds: Int) {
        self.id = UUID()
        self.configID = config.id
        self.configName = config.name
        self.payload = (try? JSONEncoder().encode(config)) ?? Data()
        self.practisedAt = Date()
        self.wasCompleted = wasCompleted
        self.elapsedSeconds = elapsedSeconds
        self.totalSeconds = config.totalDurationSeconds
    }

    func config() -> TimerConfig? {
        try? JSONDecoder().decode(TimerConfig.self, from: payload)
    }
}
