import SwiftUI

/// A transparent breakdown of how the Smart Scan health score was computed.
/// Replaces the black-box `Int` so every deduction is visible to the user.
struct HealthScoreBreakdown: Sendable {
    let baseScore: Int
    let deductions: [Deduction]
    let finalScore: Int
    let tier: HealthScore.Tier
    let explanation: String

    /// Convenience for displaying the headline number.
    var asHealthScore: HealthScore { HealthScore(value: finalScore) }

    struct Deduction: Identifiable, Sendable, Hashable {
        let id: UUID
        let reason: Reason
        let points: Int

        init(reason: Reason, points: Int) {
            self.id = UUID()
            self.reason = reason
            self.points = points
        }

        enum Reason: Sendable, Hashable {
            case junkOver1GB(bytes: Int64)
            case junkOver5GB(bytes: Int64)
            case junkOver10GB(bytes: Int64)
            case diskOver80(percent: Int)
            case diskOver90(percent: Int)
            case manyApps(count: Int)
            case manyLeftovers(count: Int)
            case oldDownloads(bytes: Int64)

            var displayText: String {
                switch self {
                case .junkOver1GB(let b):   return String(localized: "Over 1 GB of junk found (\(b.compactBytes))")
                case .junkOver5GB(let b):   return String(localized: "Over 5 GB of junk found (\(b.compactBytes))")
                case .junkOver10GB(let b):  return String(localized: "Over 10 GB of junk found (\(b.compactBytes))")
                case .diskOver80(let p):    return String(localized: "Disk is \(p)% full")
                case .diskOver90(let p):    return String(localized: "Disk is \(p)% full — critically low")
                case .manyApps(let c):      return String(localized: "\(c) applications installed")
                case .manyLeftovers(let c): return String(localized: "\(c) leftover items from uninstalled apps")
                case .oldDownloads(let b):  return String(localized: "\(b.compactBytes) of old downloads")
                }
            }

            var icon: String {
                switch self {
                case .junkOver1GB, .junkOver5GB, .junkOver10GB: return "trash.circle.fill"
                case .diskOver80, .diskOver90:                  return "externaldrive.fill"
                case .manyApps:                                 return "app.badge"
                case .manyLeftovers:                            return "xmark.app.fill"
                case .oldDownloads:                             return "arrow.down.circle.fill"
                }
            }
        }
    }

    /// Compute a fully explained score from the same inputs the old
    /// `HealthScore.compute` used.
    static func compute(
        junkBytes: Int64,
        diskUsageFraction: Double,
        appCount: Int,
        leftoverCount: Int = 0,
        oldDownloadBytes: Int64 = 0
    ) -> HealthScoreBreakdown {

        var deductions: [Deduction] = []
        let base = 100

        // Junk tiers — only the most severe band applies.
        if junkBytes > 10_000_000_000 {
            deductions.append(.init(reason: .junkOver10GB(bytes: junkBytes), points: 40))
        } else if junkBytes > 5_000_000_000 {
            deductions.append(.init(reason: .junkOver5GB(bytes: junkBytes), points: 30))
        } else if junkBytes > 1_000_000_000 {
            deductions.append(.init(reason: .junkOver1GB(bytes: junkBytes), points: 10))
        }

        // Disk usage
        let diskPercent = Int(diskUsageFraction * 100)
        if diskUsageFraction > 0.90 {
            deductions.append(.init(reason: .diskOver90(percent: diskPercent), points: 30))
        } else if diskUsageFraction > 0.80 {
            deductions.append(.init(reason: .diskOver80(percent: diskPercent), points: 20))
        }

        // App count
        if appCount > 100 {
            deductions.append(.init(reason: .manyApps(count: appCount), points: 10))
        }

        // Leftovers (optional — populated when AppScanner has done a deep scan)
        if leftoverCount > 20 {
            deductions.append(.init(reason: .manyLeftovers(count: leftoverCount), points: 5))
        }

        // Old downloads
        if oldDownloadBytes > 1_000_000_000 {
            deductions.append(.init(reason: .oldDownloads(bytes: oldDownloadBytes), points: 5))
        }

        let totalDeducted = deductions.reduce(0) { $0 + $1.points }
        let final = max(0, base - totalDeducted)
        let tier = HealthScore(value: final).tier
        let explanation: String = deductions.isEmpty
            ? String(localized: "Your Mac is in great shape — no significant issues found.")
            : String(localized: "\(deductions.count) issues found that affect your score.")

        return HealthScoreBreakdown(
            baseScore: base,
            deductions: deductions,
            finalScore: final,
            tier: tier,
            explanation: explanation
        )
    }
}
