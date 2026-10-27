import SwiftUI

/// A transparent breakdown of how the Smart Scan health score was computed.
/// Every deduction is visible, and `potentialScore` shows what cleaning the
/// safe items would do, so the number is something you can act on.
struct HealthScoreBreakdown: Sendable {
    let baseScore: Int
    let deductions: [Deduction]
    let finalScore: Int
    /// The score once the safe, pre-selected junk is gone. Equal to
    /// `finalScore` when cleaning would change nothing.
    let potentialScore: Int
    let tier: HealthScore.Tier
    let explanation: String

    /// Convenience for displaying the headline number.
    var asHealthScore: HealthScore { HealthScore(value: finalScore) }

    /// Points a cleanup of the safe items would win back.
    var potentialGain: Int { max(0, potentialScore - finalScore) }

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
            case storagePressure(percent: Int, freeBytes: Int64?)
            case reclaimableJunk(safeBytes: Int64, reviewBytes: Int64)
            case manyApps(count: Int)

            var displayText: String {
                switch self {
                case .storagePressure(let p, let free):
                    if let free {
                        return String(localized: "Disk is \(p)% full, \(free.compactBytes) free")
                    }
                    return String(localized: "Disk is \(p)% full")
                case .reclaimableJunk(let safe, let review):
                    if safe > 0 && review > 0 {
                        return String(localized: "\(safe.compactBytes) of safe junk and \(review.compactBytes) to review")
                    }
                    if safe > 0 {
                        return String(localized: "\(safe.compactBytes) of junk that is safe to remove")
                    }
                    return String(localized: "\(review.compactBytes) of files worth reviewing")
                case .manyApps(let c):
                    return String(localized: "\(c) applications installed")
                }
            }

            var icon: String {
                switch self {
                case .storagePressure:  return "externaldrive.fill"
                case .reclaimableJunk:  return "trash.circle.fill"
                case .manyApps:         return "app.badge"
                }
            }
        }
    }

    // MARK: - Scoring

    /// The most each factor can take off. Together they leave a floor of 20,
    /// so a full disk alone never reads as a broken Mac.
    static let maxStoragePenalty = 40.0
    static let maxJunkPenalty = 35.0
    static let maxAppsPenalty = 5.0

    /// Junk you would have to look at first counts for a quarter of junk
    /// that is safe to remove outright.
    static let reviewWeight = 0.25

    /// Computes a fully explained score.
    /// - safeJunkBytes: junk the review flow would pre-select.
    /// - reviewJunkBytes: junk that needs a human decision.
    /// - diskUsageFraction: 0...1, how full the startup disk is.
    /// - diskFreeBytes: free space on the startup disk, when known.
    static func compute(
        safeJunkBytes: Int64,
        reviewJunkBytes: Int64 = 0,
        diskUsageFraction: Double,
        diskFreeBytes: Int64? = nil,
        appCount: Int
    ) -> HealthScoreBreakdown {

        let deductions = makeDeductions(
            safeJunk: safeJunkBytes, reviewJunk: reviewJunkBytes,
            usedFraction: diskUsageFraction, freeBytes: diskFreeBytes, appCount: appCount)
        let final = max(0, 100 - deductions.reduce(0) { $0 + $1.points })

        // Same Mac after the safe junk is cleaned: more room, no safe junk.
        var potentialFraction = diskUsageFraction
        var potentialFree = diskFreeBytes
        if let free = diskFreeBytes, free > 0, diskUsageFraction < 1 {
            let total = Double(free) / (1 - diskUsageFraction)
            potentialFraction = max(0, diskUsageFraction - Double(safeJunkBytes) / total)
            potentialFree = free + safeJunkBytes
        }
        let potential = max(final, 100 - makeDeductions(
            safeJunk: 0, reviewJunk: reviewJunkBytes,
            usedFraction: potentialFraction, freeBytes: potentialFree, appCount: appCount)
            .reduce(0) { $0 + $1.points })

        let explanation = deductions.isEmpty
            ? String(localized: "Your Mac is in great shape. No significant issues found.")
            : String(localized: "\(deductions.count) issues found that affect your score.")

        return HealthScoreBreakdown(
            baseScore: 100,
            deductions: deductions,
            finalScore: final,
            potentialScore: potential,
            tier: HealthScore(value: final).tier,
            explanation: explanation
        )
    }

    private static func makeDeductions(
        safeJunk: Int64, reviewJunk: Int64,
        usedFraction: Double, freeBytes: Int64?, appCount: Int
    ) -> [Deduction] {
        var result: [Deduction] = []

        let storage = Int(storagePenalty(usedFraction: usedFraction, freeBytes: freeBytes).rounded())
        if storage > 0 {
            result.append(.init(
                reason: .storagePressure(percent: Int(usedFraction * 100), freeBytes: freeBytes),
                points: storage))
        }

        let junk = Int(junkPenalty(safeBytes: safeJunk, reviewBytes: reviewJunk).rounded())
        if junk > 0 {
            result.append(.init(
                reason: .reclaimableJunk(safeBytes: safeJunk, reviewBytes: reviewJunk),
                points: junk))
        }

        let apps = Int(appsPenalty(count: appCount).rounded())
        if apps > 0 {
            result.append(.init(reason: .manyApps(count: appCount), points: apps))
        }
        return result
    }

    /// 0 at `lower`, 1 at `upper`, linear in between. Works in either
    /// direction, so `from: 100, to: 20` reads "0 at 100, 1 at 20".
    static func ramp(_ value: Double, from lower: Double, to upper: Double) -> Double {
        guard upper != lower else { return value >= upper ? 1 : 0 }
        return min(1, max(0, (value - lower) / (upper - lower)))
    }

    /// A full disk only hurts when there is little room left in absolute
    /// terms: 96% of a 4 TB drive is still 160 GB. Without a free-space
    /// figure it falls back to the share alone.
    static func storagePenalty(usedFraction: Double, freeBytes: Int64?) -> Double {
        let byShare = maxStoragePenalty * ramp(usedFraction, from: 0.75, to: 0.97)
        guard let freeBytes else { return byShare }
        let freeGB = Double(freeBytes) / 1_000_000_000
        let roominess = ramp(freeGB, from: 100, to: 20)          // 0 = plenty of room
        let byRoom = maxStoragePenalty * ramp(freeGB, from: 15, to: 3)
        return min(maxStoragePenalty, max(byShare * roominess, byRoom))
    }

    /// Smooth from 0.5 GB (nothing to worry about) to 15 GB (as bad as it gets).
    static func junkPenalty(safeBytes: Int64, reviewBytes: Int64) -> Double {
        let weighted = Double(safeBytes) + reviewWeight * Double(reviewBytes)
        return maxJunkPenalty * ramp(weighted / 1_000_000_000, from: 0.5, to: 15)
    }

    /// 0 up to 100 apps, full at 200.
    static func appsPenalty(count: Int) -> Double {
        maxAppsPenalty * ramp(Double(count), from: 100, to: 200)
    }
}
