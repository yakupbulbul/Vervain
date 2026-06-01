import Foundation

/// Canonical, centralised rules for whether a `CleanupItem` may be selected
/// by default. This is the *only* place these rules live — every scanner must
/// route through here so the safety policy is auditable and consistent.
///
/// Rules (in priority order):
/// 1. risky items   → never default-on
/// 2. unknown conf. → never default-on
/// 3. low conf.     → never default-on
/// 4. .oldDownload reason → never default-on (user-owned files)
/// 5. .appLeftover with low/medium confidence → never default-on
/// 6. review-risk items → never default-on (require user attention)
/// 7. safe + (high | medium) → default-on
enum CleanupSelectionPolicy {

    static func defaultSelection(
        risk: CleanupRiskLevel,
        confidence: CleanupConfidenceLevel,
        reason: CleanupReason
    ) -> Bool {

        // Rule 1: never auto-select risky items.
        if risk == .risky { return false }

        // Rule 2 & 3: confidence must be at least medium.
        if confidence == .unknown || confidence == .low { return false }

        // Rule 4: downloads are user-owned — never auto-select.
        if case .oldDownload = reason { return false }
        if case .download = reason    { return false }

        // Rule 5: app leftovers require high confidence to be auto-selected.
        if case .appLeftover = reason {
            return confidence == .high && risk == .safe
        }

        // Rule 6: review-risk items always need user attention.
        if risk == .review { return false }

        // Rule 7: safe + (high|medium) confidence may be auto-selected.
        return risk == .safe && (confidence == .high || confidence == .medium)
    }
}
