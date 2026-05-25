import Foundation
import AppKit

/// Probes whether the app likely has Full Disk Access by attempting to read
/// a few common TCC-protected paths. Returns a `FullDiskAccessStatus` so the
/// UI can show actionable guidance without misfiring when access *is* granted.
///
/// macOS gives no first-party API to query Full Disk Access, so this is a
/// best-effort probe: if every probed path is readable, FDA is *likely*
/// granted. If the probes mostly fail, FDA is *likely* denied.
actor FullDiskAccessProbe {

    /// Cached result so we don't re-probe on every UI update. Refreshed by
    /// calling `probe(force: true)`.
    private var cached: FullDiskAccessStatus = .unknown

    func currentStatus() -> FullDiskAccessStatus { cached }

    /// Re-runs the probe. Cheap (3 syscalls), safe to call on launch and
    /// after the user returns from System Settings.
    @discardableResult
    func probe(force: Bool = false) -> FullDiskAccessStatus {
        if !force, cached != .unknown { return cached }

        let probePaths: [String] = [
            // Apple Mail data — only readable with FDA
            NSString(string: "~/Library/Mail").expandingTildeInPath,
            // Safari bookmarks — protected
            NSString(string: "~/Library/Safari").expandingTildeInPath,
            // System log — protected
            "/private/var/db/diagnostics",
        ]

        let fm = FileManager.default
        var readable = 0
        var probed = 0
        for path in probePaths {
            // Skip paths that don't exist on this machine.
            guard fm.fileExists(atPath: path) else { continue }
            probed += 1
            // Try to enumerate one level — that's what triggers TCC.
            if (try? fm.contentsOfDirectory(atPath: path)) != nil {
                readable += 1
            }
        }

        let status: FullDiskAccessStatus
        if probed == 0 {
            status = .unknown
        } else if readable == probed {
            status = .likelyGranted
        } else if readable == 0 {
            status = .likelyDenied
        } else {
            // Partial — treat as denied so we show guidance.
            status = .likelyDenied
        }
        cached = status
        return status
    }

    /// Opens the System Settings pane for Full Disk Access.
    @MainActor
    static func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }
}

enum FullDiskAccessStatus: Sendable, Equatable {
    case unknown
    case likelyGranted
    case likelyDenied

    var label: String {
        switch self {
        case .unknown:        return "Permission status unknown"
        case .likelyGranted:  return "Full Disk Access appears granted"
        case .likelyDenied:   return "Full Disk Access required"
        }
    }

    var requiresUserAction: Bool { self == .likelyDenied }
}
