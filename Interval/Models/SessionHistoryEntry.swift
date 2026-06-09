import Foundation
import SwiftData

// MARK: - Session history

// One entry is recorded every time a session ends (natural completion or manual stop)
// and the user taps "Back to Library" from the session-done overlay.
// The full config is stored as JSON so deleted timers can still be shown and restored.

@Model
final class SessionHistoryEntry {
    @Attribute(.unique) var id: UUID
    var configID: UUID          // original timer ID — used to detect if it was deleted
    var configName: String      // cached for display without decoding
    var payload: Data           // full TimerConfig JSON
    var practisedAt: Date
    var wasCompleted: Bool      // true = natural end, false = manually stopped
    var elapsedSeconds: Int
    var totalSeconds: Int

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
