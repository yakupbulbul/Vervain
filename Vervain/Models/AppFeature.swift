import SwiftUI

enum AppFeature: String, CaseIterable, Identifiable, Hashable {
    case smartScan
    case systemJunk
    case appUninstaller
    case diskAnalyzer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .smartScan:      return String(localized: "Smart Scan")
        case .systemJunk:     return String(localized: "System Junk")
        case .appUninstaller: return String(localized: "App Uninstaller")
        case .diskAnalyzer:   return String(localized: "Disk Analyzer")
        }
    }

    var icon: String {
        switch self {
        case .smartScan:      return "leaf.fill"
        case .systemJunk:     return "arrow.3.trianglepath"
        case .appUninstaller: return "leaf.arrow.circlepath"
        case .diskAnalyzer:   return "tree.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .smartScan:      return Theme.smartScanAccent
        case .systemJunk:     return Theme.systemJunkAccent
        case .appUninstaller: return Theme.appUninstallerAccent
        case .diskAnalyzer:   return Theme.diskAnalyzerAccent
        }
    }

    var description: String {
        switch self {
        case .smartScan:      return String(localized: "Nurture your Mac's health")
        case .systemJunk:     return String(localized: "Recycle unused files")
        case .appUninstaller: return String(localized: "Gently remove apps")
        case .diskAnalyzer:   return String(localized: "See what's growing")
        }
    }
}
