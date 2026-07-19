import Foundation
@preconcurrency import UserNotifications

// MARK: - Trial-end reminder
//
// The paywall promises "we'll remind you on day 5, before your trial ends".
// This delivers on that promise: after a trial-eligible annual purchase we
// request notification permission (if not yet determined) and schedule one
// local notification 5 days out — two days before billing starts on day 7.

enum TrialReminderManager {
    private static let notificationID = "trialEndReminder"
    private static let reminderDelay: TimeInterval = 5 * 24 * 60 * 60   // day 5

    /// Call after a successful purchase of the annual plan that started a
    /// free trial. Safe to call repeatedly — the reminder is replaced.
    static func scheduleReminder() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = NSLocalizedString("Your free trial ends in 2 days", comment: "Trial reminder notification title")
            content.body = NSLocalizedString("Enjoying Cadence Pro? Then there's nothing to do. Not for you? Cancel anytime.", comment: "Trial reminder notification body")
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: reminderDelay, repeats: false)
            let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger)
            center.add(request)
        }
    }
}
