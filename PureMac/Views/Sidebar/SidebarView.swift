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
                .background(Color.white.opacity(0.1))

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
        .background(Color(red: 0.11, green: 0.11, blue: 0.18))
    }

    // MARK: - Sub-views

    private var appHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 1) {
                Text("PureMac")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Text("System Cleaner")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
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
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
            Text("\(score.value)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(score.tier.color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
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
                    .foregroundStyle(.white)
                Text(feature.description)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
            }
        } icon: {
            Image(systemName: feature.icon)
                .foregroundStyle(feature.accentColor)
                .frame(width: 20)
        }
        .padding(.vertical, 3)
    }
}
