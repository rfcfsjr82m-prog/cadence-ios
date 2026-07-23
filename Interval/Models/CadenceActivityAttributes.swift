import Foundation
import ActivityKit

// MARK: - CadenceActivityAttributes
//
// Shared between the main app target (starts/updates the activity) and the
// CadenceWidget extension target (renders the live view on the lock screen).
//
// `timerName`  — static, set once at activity start
// ContentState — carries real-time countdown anchors so the system renders the
//                countdown itself on the lock screen. This means the timer keeps
//                counting correctly even while the app is suspended in the
//                background — it does not depend on the app pushing updates.

struct CadenceActivityAttributes: ActivityAttributes, Sendable {
    struct ContentState: Codable, Hashable, Sendable {
        /// Name of the currently active interval block  (e.g. "Work")
        var blockLabel: String
        /// Round text shown in the corner  (e.g. "3 / 8")
        var roundLabel: String
        /// Block colour as a hex string  (e.g. "4A90D9")
        var blockColorHex: String
        /// Whether the timer is paused
        var isPaused: Bool

        // ── Real-time countdown anchors ──────────────────────────────────────
        // The lock-screen widget renders `Text(timerInterval:)` between these
        // dates, so iOS counts the timer down live with no app involvement.
        /// Wall-clock time the current block started
        var blockStartDate: Date
        /// Wall-clock time the current block ends
        var blockEndDate: Date
        /// Wall-clock time the whole session started
        var sessionStartDate: Date
        /// Wall-clock time the whole session ends
        var sessionEndDate: Date

        // ── Static fallbacks shown while paused ──────────────────────────────
        // A live countdown can't be frozen, so when paused the widget shows
        // these fixed values instead.
        /// Seconds remaining in the current block, captured at pause
        var blockLeftAtPause: Int
        /// Seconds remaining in the whole session, captured at pause
        var totalLeftAtPause: Int
    }

    /// Session / timer name — set once, never changes during the activity
    var timerName: String
}
