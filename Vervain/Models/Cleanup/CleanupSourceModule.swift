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
    case projectArtifacts
    case aiModels
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
        case .projectArtifacts: return "Project Artifacts"
        case .aiModels:        return "AI Models"
        case .privacy:         return "Privacy"
        case .performance:     return "Performance"
        }
    }
}
