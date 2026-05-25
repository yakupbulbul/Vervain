import SwiftUI

/// Card surfaced in Smart Scan results. Each recommendation has a severity
/// dot, description, optional recoverable-size hint, and a CTA button that
/// either opens the universal review or jumps to a module.
struct RecommendationCard: View {
    let recommendation: SmartRecommendation
    let onAction: (SmartRecommendation.Action) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            severityDot
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(recommendation.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    if recommendation.estimatedRecoverableBytes > 0 {
                        SizeBadge(
                            bytes: recommendation.estimatedRecoverableBytes,
                            color: .orange
                        )
                    }
                }
                Text(recommendation.description)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Spacer()
                    Button {
                        onAction(recommendation.action)
                    } label: {
                        HStack(spacing: 4) {
                            Text(recommendation.action.ctaLabel)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(recommendation.severity.color)
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(recommendation.severity.color.opacity(0.25), lineWidth: 1)
        )
    }

    private var severityDot: some View {
        ZStack {
            Circle()
                .fill(recommendation.severity.color.opacity(0.18))
                .frame(width: 32, height: 32)
            Image(systemName: recommendation.severity.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(recommendation.severity.color)
        }
    }
}
