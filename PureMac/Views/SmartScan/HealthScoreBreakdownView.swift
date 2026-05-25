import SwiftUI

/// Shows the deductions that brought the health score below 100.
/// Each row is a transparent reason + point cost so the score is not a
/// black box.
struct HealthScoreBreakdownView: View {
    let breakdown: HealthScoreBreakdown

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How we calculated your score")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
                .tracking(0.8)

            if breakdown.deductions.isEmpty {
                emptyState
            } else {
                pathRow
                deductionsList
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }

    private var emptyState: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
                .font(.system(size: 18))
            Text(breakdown.explanation)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    /// Visual path: 100 → ... → final
    private var pathRow: some View {
        HStack(spacing: 6) {
            scorePill(breakdown.baseScore, color: .green)
            ForEach(breakdown.deductions) { d in
                Image(systemName: "arrow.right")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.3))
                scorePill(
                    runningTotal(after: d),
                    color: pillColor(for: runningTotal(after: d))
                )
            }
        }
        .font(.system(.caption, design: .rounded).weight(.semibold))
    }

    private var deductionsList: some View {
        VStack(spacing: 6) {
            ForEach(breakdown.deductions) { d in
                HStack(spacing: 10) {
                    Image(systemName: d.reason.icon)
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 18)
                    Text(d.reason.displayText)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    Text("-\(d.points)")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Color.red.opacity(0.12), in: Capsule())
                }
            }
        }
    }

    // MARK: - Helpers

    private func scorePill(_ value: Int, color: Color) -> some View {
        Text("\(value)")
            .padding(.horizontal, 8).padding(.vertical, 3)
            .foregroundStyle(.white)
            .background(color.opacity(0.7), in: Capsule())
    }

    private func pillColor(for score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 50..<80:  return .yellow
        default:       return .red
        }
    }

    private func runningTotal(after deduction: HealthScoreBreakdown.Deduction) -> Int {
        var total = breakdown.baseScore
        for d in breakdown.deductions {
            total -= d.points
            if d.id == deduction.id { break }
        }
        return max(0, total)
    }
}
