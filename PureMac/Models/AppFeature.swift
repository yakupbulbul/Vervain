import SwiftUI

enum AppFeature: String, CaseIterable, Identifiable, Hashable {
    case smartScan       = "Smart Scan"
    case systemJunk      = "System Junk"
    case appUninstaller  = "App Uninstaller"
    case diskAnalyzer    = "Disk Analyzer"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .smartScan:      return "shield.lefthalf.filled"
        case .systemJunk:     return "trash.circle.fill"
        case .appUninstaller: return "xmark.app.fill"
        case .diskAnalyzer:   return "chart.pie.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .smartScan:      return .blue
        case .systemJunk:     return .orange
        case .appUninstaller: return .red
        case .diskAnalyzer:   return .purple
        }
    }

    var description: String {
        switch self {
        case .smartScan:      return "Check overall Mac health"
        case .systemJunk:     return "Free up wasted space"
        case .appUninstaller: return "Remove apps completely"
        case .diskAnalyzer:   return "Visualize disk usage"
        }
    }
}
