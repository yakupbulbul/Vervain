import Foundation
import UserNotifications

/// When the weekly reminder fires. Weekday uses Calendar numbering
/// (1 = Sunday … 7 = Saturday).
struct ReminderSchedule: Equatable, Sendable {
    var weekday: Int
    var hour: Int

    static let weekdayKey = "reminderWeekday"
    static let hourKey = "reminderHour"
    static let standard = ReminderSchedule(weekday: 2, hour: 10)   // Monday, 10:00

    static func fromDefaults(_ defaults: UserDefaults = .standard) -> ReminderSchedule {
        let weekday = defaults.object(forKey: weekdayKey) as? Int ?? standard.weekday
        let hour = defaults.object(forKey: hourKey) as? Int ?? standard.hour
        return ReminderSchedule(weekday: min(7, max(1, weekday)), hour: min(23, max(0, hour)))
    }

    var dateComponents: DateComponents {
        var components = DateComponents()
        components.weekday = weekday
        components.hour = hour
        components.minute = 0
        return components
    }
}

/// Local notifications: the optional weekly scan reminder and one-off alerts.
/// Purely local: no network, no push, nothing leaves the Mac.
@MainActor
enum ReminderScheduler {
    nonisolated static let identifier = "app.vervain.weeklyReminder"
    nonisolated static let lowDiskIdentifier = "app.vervain.lowDisk"

    /// Asks for permission to show notifications (once; macOS remembers the answer).
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Turns the reminder on or off. Returns false if it could not be enabled
    /// (e.g. the user denied notification permission).
    @discardableResult
    static func setEnabled(_ enabled: Bool, schedule: ReminderSchedule? = nil) async -> Bool {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard enabled else { return true }
        guard await requestAuthorization() else { return false }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Time for a Mac checkup")
        content.body = String(localized: "Run a Vervain scan to see what can be cleaned up.")

        let when = (schedule ?? ReminderSchedule.fromDefaults()).dateComponents
        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        do {
            try await center.add(request)
            return true
        } catch {
            return false
        }
    }

    /// Shows a notification right away (used by the low-disk alert).
    static func notifyNow(id: String, title: String, body: String) async {
        guard await requestAuthorization() else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}

/// Routes a tap on a Vervain notification to "start a Smart Scan".
final class NotificationRouter: NSObject, @preconcurrency UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationRouter()
    static let startScanNotification = Notification.Name("app.vervain.startSmartScan")

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let id = response.notification.request.identifier
        guard id == ReminderScheduler.identifier || id == ReminderScheduler.lowDiskIdentifier else { return }
        await MainActor.run {
            NotificationCenter.default.post(name: Self.startScanNotification, object: nil)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
