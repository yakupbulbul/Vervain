import Foundation

/// Which feature produced this cleanup item.
/// Used for grouping in the review screen and for telemetry-free attribution.
enum CleanupSourceModule: String, CaseIterable, Sendable, Hashable {
    case smartScan
    case systemJunk
    case appUninstaller
    case diskAnalyzer
    case largeOldFiles
    case duplicates
    case privacy
    case performance

    var label: String {
        switch self {
        case .smartScan:       return "Smart Scan"
        case .systemJunk:      return "System Junk"
        case .appUninstaller:  return "App Uninstaller"
        case .diskAnalyzer:    return "Disk Analyzer"
        case .largeOldFiles:   return "Large & Old Files"
        case .duplicates:      return "Duplicates"
        case .privacy:         return "Privacy"
        case .performance:     return "Performance"
        }
    }
}
