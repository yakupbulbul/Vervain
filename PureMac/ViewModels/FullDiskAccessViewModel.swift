import SwiftUI

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
        // After the user returns, recheck after a short delay.
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            status = await probe.probe(force: true)
        }
    }

    func dismissBanner() {
        isDismissedThisSession = true
    }
}
