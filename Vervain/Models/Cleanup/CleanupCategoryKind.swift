import Foundation

/// Stable identifier for cleanup categories, decoupled from display titles.
/// Used for programmatic filtering (e.g. Smart Scan recommendations)
/// so that localized titles don't break logic.
enum CleanupCategoryKind: String, Sendable {
    case oldCaches, recentCaches
    case oldLogs, recentLogs
    case languageFiles
    case oldInstallers, otherDownloads
    case trashContents
    case developerCaches, packageManagerCaches
    case appLeftovers
    case largeFiles
    case duplicates
    case browserCaches, browserHistory, browserCookies
    case launchAgents
    case orphanedData
    case deviceBackups
}
