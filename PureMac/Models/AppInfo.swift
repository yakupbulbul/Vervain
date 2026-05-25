import Foundation

/// Describes one installed application as surfaced by the App Uninstaller.
/// Storing only `URL`s (not `NSImage`) keeps the type cheap to send across
/// actor boundaries; icons are fetched on the @MainActor in the view layer.
struct AppInfo: Identifiable, Sendable {
    let id: UUID
    let name: String
    let bundleID: String
    let version: String?
    let developer: String?
    let url: URL
    let bundleSize: Int64
    let lastModifiedDate: Date?
    var leftoverItems: [CleanupItem]
    /// Sum of leftover sizes (= -1 if leftovers haven't been scanned yet).
    var leftoverSize: Int64
    /// Whether the user has marked this app for uninstall.
    var isSelected: Bool

    var totalSize: Int64 {
        bundleSize + max(0, leftoverSize)
    }
    var leftoverScanned: Bool { leftoverSize >= 0 }
    var hasLeftovers: Bool { leftoverSize > 0 }

    static func make(
        name: String,
        bundleID: String,
        version: String?,
        developer: String?,
        url: URL,
        bundleSize: Int64,
        lastModifiedDate: Date?
    ) -> AppInfo {
        AppInfo(
            id: UUID(),
            name: name,
            bundleID: bundleID,
            version: version,
            developer: developer,
            url: url,
            bundleSize: bundleSize,
            lastModifiedDate: lastModifiedDate,
            leftoverItems: [],
            leftoverSize: -1,
            isSelected: false
        )
    }
}
