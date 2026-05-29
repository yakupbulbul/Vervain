import SwiftUI

/// How risky it is to remove this item.
///
/// - `safe`   – well-understood, recoverable, low impact (e.g. old caches)
/// - `review` – user should look before deleting (e.g. recent caches, language files in signed bundles)
/// - `risky`  – could disrupt work or data (e.g. recent downloads, cookies)
enum CleanupRiskLevel: String, CaseIterable, Sendable, Comparable, Hashable {
    case safe
    case review
    case risky

    var label: String {
        switch self {
        case .safe:   return "Safe"
        case .review: return "Review"
        case .risky:  return "Risky"
        }
    }

    var icon: String {
        switch self {
        case .safe:   return "checkmark.shield.fill"
        case .review: return "exclamationmark.circle.fill"
        case .risky:  return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .safe:   return Theme.statusSafe
        case .review: return Theme.statusReview
        case .risky:  return Theme.statusRisky
        }
    }

    /// Severity ordering: safe < review < risky.
    static func < (lhs: CleanupRiskLevel, rhs: CleanupRiskLevel) -> Bool {
        let order: [CleanupRiskLevel] = [.safe, .review, .risky]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}
