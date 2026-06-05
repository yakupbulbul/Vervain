import SwiftUI

/// How confident we are that this item belongs to the category we put it in.
///
/// Used heavily by the App Uninstaller to grade leftover matches:
/// `high` = exact bundle ID match, `low` = loose substring match.
enum CleanupConfidenceLevel: String, CaseIterable, Sendable, Hashable {
    case high
    case medium
    case low
    case unknown

    var label: String {
        switch self {
        case .high:    return String(localized: "High")
        case .medium:  return String(localized: "Medium")
        case .low:     return String(localized: "Low")
        case .unknown: return String(localized: "Unknown")
        }
    }

    var color: Color {
        switch self {
        case .high:    return Theme.statusSafe
        case .medium:  return Theme.statusReview
        case .low:     return Theme.systemJunkAccent
        case .unknown: return Theme.chartOther
        }
    }

    var description: String {
        switch self {
        case .high:    return String(localized: "Exact match — very likely correct")
        case .medium:  return String(localized: "Strong match — likely correct")
        case .low:     return String(localized: "Weak match — please verify")
        case .unknown: return String(localized: "Insufficient metadata to grade")
        }
    }
}
