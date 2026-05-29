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
        case .high:    return "High"
        case .medium:  return "Medium"
        case .low:     return "Low"
        case .unknown: return "Unknown"
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
        case .high:    return "Exact match — very likely correct"
        case .medium:  return "Strong match — likely correct"
        case .low:     return "Weak match — please verify"
        case .unknown: return "Insufficient metadata to grade"
        }
    }
}
