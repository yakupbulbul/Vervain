import Foundation

struct AppInfo: Identifiable, Sendable {
    let id: UUID
    let name: String
    let bundleID: String
    let url: URL
    let bundleSize: Int64
    var leftoverFiles: [URL]
    var leftoverSize: Int64
    var isSelected: Bool

    var totalSize: Int64 { bundleSize + leftoverSize }
    var hasScannedLeftovers: Bool { !leftoverFiles.isEmpty || leftoverSize >= 0 }
}

// Separate mutable tracker used only in ViewModels
extension AppInfo {
    static func make(
        name: String,
        bundleID: String,
        url: URL,
        bundleSize: Int64
    ) -> AppInfo {
        AppInfo(
            id: UUID(),
            name: name,
            bundleID: bundleID,
            url: url,
            bundleSize: bundleSize,
            leftoverFiles: [],
            leftoverSize: -1,   // -1 = not yet scanned
            isSelected: false
        )
    }

    var leftoverScanned: Bool { leftoverSize >= 0 }
}
