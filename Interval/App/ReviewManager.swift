import Foundation

// MARK: - Manages when to show the review prompt

final class ReviewManager: @unchecked Sendable {
    static let shared = ReviewManager()

    private let completedSessionsKey = "reviewCompletedSessionsCount"
    private let nextPromptThresholdKey = "reviewNextPromptThreshold"
    private let neverShowAgainKey = "reviewNeverShowAgain"

    private init() {}

    /// Call this every time a session completes naturally.
    /// Returns true if the review prompt should be shown.
    func recordCompletedSession() -> Bool {
        guard !neverShowAgain else { return false }

        let count = completedSessions + 1
        UserDefaults.standard.set(count, forKey: completedSessionsKey)

        return count >= nextPromptThreshold
    }

    /// Call when user taps "Maybe later" — snooze for 10 more sessions.
    func snooze() {
        let threshold = completedSessions + 10
        UserDefaults.standard.set(threshold, forKey: nextPromptThresholdKey)
    }

    /// Call when user rates or sends feedback — never show again.
    func markReviewed() {
        UserDefaults.standard.set(true, forKey: neverShowAgainKey)
    }

    // MARK: - Private

    private var completedSessions: Int {
        UserDefaults.standard.integer(forKey: completedSessionsKey)
    }

    private var nextPromptThreshold: Int {
        let stored = UserDefaults.standard.integer(forKey: nextPromptThresholdKey)
        return stored == 0 ? 5 : stored  // show after 5th completed session
    }

    private var neverShowAgain: Bool {
        UserDefaults.standard.bool(forKey: neverShowAgainKey)
    }
}
