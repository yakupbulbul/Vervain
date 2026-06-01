import SwiftUI

enum AppFeature: String, CaseIterable, Identifiable, Hashable {
    case smartScan       = "Smart Scan"
    case systemJunk      = "System Junk"
    case appUninstaller  = "App Uninstaller"
    case diskAnalyzer    = "Disk Analyzer"

    var id: String { rawValue }

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
        case .smartScan:      return "Nurture your Mac's health"
        case .systemJunk:     return "Recycle unused files"
        case .appUninstaller: return "Gently remove apps"
        case .diskAnalyzer:   return "See what's growing"
        }
    }
}
