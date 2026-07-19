import Foundation

// MARK: - Manages when to show the review prompt

final class ReviewManager: @unchecked Sendable {
    static let shared = ReviewManager()

    private let completedSessionsKey = "reviewCompletedSessionsCount"
    private let nextPromptThresholdKey = "reviewNextPromptThreshold"

    private init() {}

    /// Call this every time a session completes naturally.
    /// Returns true if the review prompt should be requested.
    ///
    /// Fires at the 5th completed session, then re-arms every 10 sessions
    /// (15, 25, …). The native StoreKit dialog gives no rated/dismissed
    /// callback, so we re-arm unconditionally — iOS itself caps display at
    /// 3 times per year and never shows it again after the user has rated.
    func recordCompletedSession() -> Bool {
        let count = completedSessions + 1
        UserDefaults.standard.set(count, forKey: completedSessionsKey)

        guard count >= nextPromptThreshold else { return false }
        UserDefaults.standard.set(count + 10, forKey: nextPromptThresholdKey)
        return true
    }

    // MARK: - Private

    private var completedSessions: Int {
        UserDefaults.standard.integer(forKey: completedSessionsKey)
    }

    private var nextPromptThreshold: Int {
        let stored = UserDefaults.standard.integer(forKey: nextPromptThresholdKey)
        return stored == 0 ? 5 : stored  // show after 5th completed session
    }
}
