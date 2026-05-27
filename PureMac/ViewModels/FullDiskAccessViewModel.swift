import SwiftUI
import AppKit

/// Shared @Observable wrapper around `FullDiskAccessProbe` so any view can
/// reactively show or hide the FDA banner.
@Observable
@MainActor
final class FullDiskAccessViewModel {
    var status: FullDiskAccessStatus = .unknown
    var isDismissedThisSession = false

    private let probe = FullDiskAccessProbe()

    var shouldShowBanner: Bool {
        !isDismissedThisSession && status == .likelyDenied
    }

    /// Probe and update the published status.
    func refresh(force: Bool = false) {
        Task {
            status = await probe.probe(force: force)
        }
    }

    func openSystemSettings() {
        FullDiskAccessProbe.openSystemSettings()

        // Re-probe exactly once when the user returns to the app from System Settings.
        // This avoids the race where a fixed 1.5 s delay fires before the user has
        // finished granting access, leaving the banner visible.
        var token: NSObjectProtocol?
        token = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Remove observer immediately so it only fires once.
            if let token { NotificationCenter.default.removeObserver(token) }
            Task { @MainActor [weak self] in
                // Brief pause to let TCC write the new permission to disk.
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 s
                guard let self else { return }
                self.status = await self.probe.probe(force: true)
            }
        }
    }

    func dismissBanner() {
        isDismissedThisSession = true
    }
}
