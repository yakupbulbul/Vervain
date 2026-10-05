import Foundation
import UserNotifications

/// Optional weekly local notification that reminds the user to run a scan.
/// Purely local: no network, no push, nothing leaves the Mac.
@MainActor
enum ReminderScheduler {
    static let identifier = "app.vervain.weeklyReminder"

    /// Turns the reminder on or off. Returns false if it could not be enabled
    /// (e.g. the user denied notification permission).
    @discardableResult
    static func setEnabled(_ enabled: Bool) async -> Bool {
        let center = UNUserNotificationCenter.current()
        guard enabled else {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            return true
        }
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return false }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Time for a Mac checkup")
        content.body = String(localized: "Run a Vervain scan to see what can be cleaned up.")

        var when = DateComponents()
        when.weekday = 2   // Monday
        when.hour = 10
        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        do {
            try await center.add(request)
            return true
        } catch {
            return false
        }
    }
}
