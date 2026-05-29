import SwiftUI

struct SidebarView: View {
    @Binding var selectedFeature: AppFeature?
    @Environment(SmartScanViewModel.self) private var smartScanVM

    var body: some View {
        VStack(spacing: 0) {
            // App header
            appHeader
                .padding(.top, 24)
                .padding(.bottom, 16)

            Divider()
                .background(Theme.divider)

            // Feature list
            List(AppFeature.allCases, selection: $selectedFeature) { feature in
                SidebarRow(feature: feature)
                    .tag(feature)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            Spacer(minLength: 0)

            // Health badge
            if let score = smartScanVM.breakdown?.asHealthScore {
                healthBadge(score: score)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Theme.sidebarBackground)
    }

    // MARK: - Sub-views

    private var appHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.brandGradient())
                .frame(width: 36, height: 36)
                .background(Theme.divider, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 1) {
                Text("PureMac")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Mac Care")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.textMuted)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private func healthBadge(score: HealthScore) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(score.tier.color)
                .frame(width: 8, height: 8)
            Text(score.tier.label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text("\(score.value)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(score.tier.color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.surfaceOverlay, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Sidebar Row

struct SidebarRow: View {
    let feature: AppFeature

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(feature.rawValue)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(feature.description)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textMuted)
            }
        } icon: {
            Image(systemName: feature.icon)
                .foregroundStyle(feature.accentColor)
                .frame(width: 20)
        }
        .padding(.vertical, 3)
    }
}
