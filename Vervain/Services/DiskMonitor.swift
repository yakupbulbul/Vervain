import Foundation

/// Decides when to warn that the startup disk is almost full.
enum LowDiskPolicy {
    static let enabledKey = "lowDiskAlertEnabled"
    static let thresholdKey = "lowDiskThresholdPercent"
    static let lastNotifiedKey = "lowDiskLastNotified"
    static let defaultThreshold = 90
    static let cooldown: TimeInterval = 24 * 3_600

    /// Warn once the disk is at least `thresholdPercent` full, and then at most once a day.
    static func shouldNotify(
        usage: DiskUsage,
        thresholdPercent: Int,
        lastNotified: Date?,
        now: Date
    ) -> Bool {
        guard usage.usedFraction * 100 >= Double(thresholdPercent) else { return false }
        if let lastNotified, now.timeIntervalSince(lastNotified) < cooldown { return false }
        return true
    }
}

/// Checks free space every ten minutes while Vervain is running and posts a
/// local notification when it runs low. Nothing runs when the app is closed.
@MainActor
final class DiskMonitor {
    static let shared = DiskMonitor()

    private var task: Task<Void, Never>?
    private let interval: Duration = .seconds(600)

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkOnce()
                try? await Task.sleep(for: self?.interval ?? .seconds(600))
            }
        }
    }

    func checkOnce(defaults: UserDefaults = .standard, now: Date = Date()) async {
        guard defaults.bool(forKey: LowDiskPolicy.enabledKey),
              let usage = DiskUsage.current() else { return }
        let threshold = defaults.object(forKey: LowDiskPolicy.thresholdKey) as? Int
            ?? LowDiskPolicy.defaultThreshold
        let last = defaults.object(forKey: LowDiskPolicy.lastNotifiedKey) as? Date
        guard LowDiskPolicy.shouldNotify(usage: usage, thresholdPercent: threshold,
                                         lastNotified: last, now: now) else { return }
        defaults.set(now, forKey: LowDiskPolicy.lastNotifiedKey)
        let percent = Int((usage.usedFraction * 100).rounded())
        await ReminderScheduler.notifyNow(
            id: ReminderScheduler.lowDiskIdentifier,
            title: String(localized: "Your disk is almost full"),
            body: String(localized: "The startup disk is \(percent)% full. Open Vervain to see what can be cleaned up.")
        )
    }
}
