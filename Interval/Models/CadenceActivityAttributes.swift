import ActivityKit

// MARK: - CadenceActivityAttributes
//
// Shared between the main app target (starts/updates the activity) and the
// CadenceWidget extension target (renders the live view on the lock screen).
//
// `timerName`  — static, set once at activity start
// ContentState — updated every second while the timer runs

struct CadenceActivityAttributes: ActivityAttributes, Sendable {
    struct ContentState: Codable, Hashable, Sendable {
        /// Name of the currently active interval block  (e.g. "Work")
        var blockLabel: String
        /// Seconds remaining in the current block
        var blockLeft: Int
        /// Round text shown in the corner  (e.g. "3 / 8")
        var roundLabel: String
        /// Seconds remaining in the whole session
        var totalLeft: Int
        /// Block colour as a hex string  (e.g. "4A90D9")
        var blockColorHex: String
        /// Whether the timer is paused
        var isPaused: Bool
    }

    /// Session / timer name — set once, never changes during the activity
    var timerName: String
}
