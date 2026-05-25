import SwiftUI

/// A single actionable recommendation surfaced by Smart Scan.
/// Each recommendation links to either the universal cleanup review
/// (pre-loaded with relevant categories) or to a specific module.
struct SmartRecommendation: Identifiable, Sendable {
    let id: UUID
    let title: String
    let description: String
    let severity: Severity
    let sourceModule: CleanupSourceModule
    let action: Action
    let estimatedRecoverableBytes: Int64

    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        severity: Severity,
        sourceModule: CleanupSourceModule,
        action: Action,
        estimatedRecoverableBytes: Int64 = 0
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.severity = severity
        self.sourceModule = sourceModule
        self.action = action
        self.estimatedRecoverableBytes = estimatedRecoverableBytes
    }

    enum Severity: String, Sendable, Hashable, Comparable {
        case info
        case warning
        case critical

        var color: Color {
            switch self {
            case .info:     return .blue
            case .warning:  return .yellow
            case .critical: return .red
            }
        }

        var icon: String {
            switch self {
            case .info:     return "info.circle.fill"
            case .warning:  return "exclamationmark.circle.fill"
            case .critical: return "exclamationmark.triangle.fill"
            }
        }

        static func < (lhs: Severity, rhs: Severity) -> Bool {
            let order: [Severity] = [.info, .warning, .critical]
            return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
        }
    }

    /// What happens when the user clicks the recommendation's CTA.
    /// `categories` is intentionally captured by value (Sendable) so the
    /// view layer can hand it straight to `CleanupCoordinator.startReview`.
    enum Action: Sendable {
        case openCleanupReview(categories: [CleanupCategory], title: String)
        case openModule(AppFeature)

        var ctaLabel: String {
            switch self {
            case .openCleanupReview: return "Review & Clean"
            case .openModule:        return "Open"
            }
        }
    }
}
