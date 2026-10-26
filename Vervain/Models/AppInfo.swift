import Foundation

/// Where an app came from, when that can be told from the bundle.
enum AppSource: String, Sendable {
    case appStore
    case setapp
    case other

    var label: String? {
        switch self {
        case .appStore: return String(localized: "App Store")
        case .setapp:   return String(localized: "Setapp")
        case .other:    return nil
        }
    }
}

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
    /// Last time the user opened the app, from Spotlight (nil if never / unknown).
    let lastUsedDate: Date?
    let source: AppSource
    /// An Apple app the user is allowed to remove (Xcode, iWork, GarageBand, iMovie).
    let isAppleApp: Bool
    var leftoverItems: [CleanupItem]
    /// Sum of leftover sizes (= -1 if leftovers haven't been scanned yet).
    var leftoverSize: Int64
    /// Whether the user has marked this app for uninstall.
    var isSelected: Bool

    var totalSize: Int64 {
        bundleSize + max(0, leftoverSize)
    }
    var leftoverScanned: Bool { leftoverSize >= 0 }

    /// True if the app has not been opened for `months` months. Falls back to
    /// the bundle's modification date when Spotlight has no last-used date.
    func isUnused(forMonths months: Int, now: Date = Date()) -> Bool {
        guard let reference = lastUsedDate ?? lastModifiedDate else { return false }
        let cutoff = now.addingTimeInterval(-Double(months) * 30 * 86_400)
        return reference < cutoff
    }
    var hasLeftovers: Bool { leftoverSize > 0 }

    static func make(
        name: String,
        bundleID: String,
        version: String?,
        developer: String?,
        url: URL,
        bundleSize: Int64,
        lastModifiedDate: Date?,
        lastUsedDate: Date? = nil,
        source: AppSource = .other,
        isAppleApp: Bool = false
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
            lastUsedDate: lastUsedDate,
            source: source,
            isAppleApp: isAppleApp,
            leftoverItems: [],
            leftoverSize: -1,
            isSelected: false
        )
    }
}
