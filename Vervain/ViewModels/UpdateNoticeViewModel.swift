import Foundation

/// Holds the "new version available" notice shown at the top of the window.
/// It only does anything when the user has turned on the automatic check.
@Observable
@MainActor
final class UpdateNoticeViewModel {
    struct Notice: Equatable {
        let version: String
        let url: URL
    }

    private(set) var notice: Notice?

    private let defaults: UserDefaults
    private let currentVersion: String
    private let check: @Sendable (String) async -> UpdateChecker.Outcome

    init(
        defaults: UserDefaults = .standard,
        currentVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0",
        check: @escaping @Sendable (String) async -> UpdateChecker.Outcome = { await UpdateChecker.check(current: $0) }
    ) {
        self.defaults = defaults
        self.currentVersion = currentVersion
        self.check = check
    }

    /// Runs the check when the user opted in and it has not run in the last day.
    /// The time is saved before the request, so a failed check is not retried on
    /// every launch.
    func checkIfDue(now: Date = Date()) async {
        let lastCheck = defaults.object(forKey: UpdateCheckPolicy.lastCheckKey) as? Date
        guard UpdateCheckPolicy.isDue(
            enabled: defaults.bool(forKey: UpdateCheckPolicy.enabledKey),
            lastCheck: lastCheck,
            now: now
        ) else { return }

        defaults.set(now, forKey: UpdateCheckPolicy.lastCheckKey)
        guard case .available(let version, let url) = await check(currentVersion) else { return }
        guard defaults.string(forKey: UpdateCheckPolicy.dismissedVersionKey) != version else { return }
        notice = Notice(version: version, url: url)
    }

    /// Hides the notice and stays quiet about this version.
    func dismiss() {
        guard let notice else { return }
        defaults.set(notice.version, forKey: UpdateCheckPolicy.dismissedVersionKey)
        self.notice = nil
    }
}
