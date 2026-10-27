import SwiftUI

struct HealthScore: Sendable {
    let value: Int  // 0–100

    var tier: Tier {
        switch value {
        case 80...100: return .good
        case 50..<80:  return .warning
        default:       return .critical
        }
    }

    enum Tier: Sendable {
        case good, warning, critical

        var color: Color {
            switch self {
            case .good:     return Theme.statusSafe
            case .warning:  return Theme.statusReview
            case .critical: return Theme.statusRisky
            }
        }

        var gradientColors: [Color] {
            switch self {
            case .good:     return Theme.healthGood
            case .warning:  return Theme.healthWarning
            case .critical: return Theme.healthCritical
            }
        }

        var label: String {
            switch self {
            case .good:     return "Excellent"
            case .warning:  return "Fair"
            case .critical: return "Poor"
            }
        }
    }
}
