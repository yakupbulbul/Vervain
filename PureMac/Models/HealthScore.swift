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
            case .good:     return .green
            case .warning:  return .yellow
            case .critical: return .red
            }
        }

        var gradientColors: [Color] {
            switch self {
            case .good:     return [.green, .mint]
            case .warning:  return [.yellow, .orange]
            case .critical: return [.red, .pink]
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

    /// Computes a health score based on system state.
    /// - junkBytes: total junk found on disk
    /// - diskUsageFraction: 0.0–1.0, how full the startup disk is
    /// - appCount: number of installed apps
    static func compute(
        junkBytes: Int64,
        diskUsageFraction: Double,
        appCount: Int
    ) -> HealthScore {
        var score = 100
        // Junk deductions
        if junkBytes > 10_000_000_000 { score -= 40 }
        else if junkBytes > 5_000_000_000 { score -= 30 }
        else if junkBytes > 1_000_000_000 { score -= 10 }
        // Disk usage deductions
        if diskUsageFraction > 0.90 { score -= 30 }
        else if diskUsageFraction > 0.80 { score -= 20 }
        // App bloat deduction
        if appCount > 100 { score -= 10 }
        return HealthScore(value: max(0, score))
    }
}
