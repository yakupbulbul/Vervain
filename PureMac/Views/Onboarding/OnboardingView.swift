import SwiftUI

/// First-launch sheet that states PureMac's privacy and safety promises
/// upfront. Persisted in UserDefaults so it only appears once per install.
struct OnboardingView: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    promise(icon: "hand.raised.fill", color: Theme.smartScanAccent,
                            title: "Private by design",
                            body: "PureMac never sends data anywhere. No telemetry, no analytics, no account. Everything runs on this Mac.")
                    promise(icon: "arrow.3.trianglepath", color: Theme.systemJunkAccent,
                            title: "Trash only — nothing is permanently deleted",
                            body: "Every cleanup moves files to the Trash. You can restore anything until you empty it yourself.")
                    promise(icon: "eye.fill", color: Theme.statusSafe,
                            title: "Review before you clean",
                            body: "Nothing is ever removed without a review screen. Risky or low-confidence items are never selected by default.")
                    promise(icon: "binoculars.fill", color: Theme.diskAnalyzerAccent,
                            title: "Optional Full Disk Access",
                            body: "PureMac asks for Full Disk Access only so it can scan your protected folders. You can decline — partial results will still work.")
                }
                .padding(28)
            }
            Divider().background(Theme.divider)
            HStack {
                Spacer()
                Button("Get Started") {
                    UserDefaults.standard.set(true, forKey: Self.onboardingShownKey)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent).controlSize(.large).tint(Theme.brandPrimary)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
        }
        .frame(width: 560, height: 540)
        .background(Theme.background)
        .foregroundStyle(Theme.textPrimary)
    }

    static let onboardingShownKey = "com.yakupbulbul.PureMac.onboardingShown"
    static var hasShown: Bool {
        UserDefaults.standard.bool(forKey: onboardingShownKey)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(Theme.brandGradient())
            Text("Welcome to PureMac").font(.title.bold())
            Text("A gentle way to care for your Mac.")
                .font(.title3).foregroundStyle(Theme.textSecondary)
        }
    }

    private func promise(icon: String, color: Color,
                         title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(color.opacity(0.18)).frame(width: 36, height: 36)
                Image(systemName: icon).foregroundStyle(color)
                    .font(.system(size: 16, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(body).font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
