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
                    promise(icon: "lock.shield.fill", color: .blue,
                            title: "Private by design",
                            body: "PureMac never sends data anywhere. No telemetry, no analytics, no account. Everything runs on this Mac.")
                    promise(icon: "trash.circle.fill", color: .orange,
                            title: "Trash only — nothing is permanently deleted",
                            body: "Every cleanup moves files to the Trash. You can restore anything until you empty it yourself.")
                    promise(icon: "checkmark.shield.fill", color: .green,
                            title: "Review before you clean",
                            body: "Nothing is ever removed without a review screen. Risky or low-confidence items are never selected by default.")
                    promise(icon: "magnifyingglass", color: .purple,
                            title: "Optional Full Disk Access",
                            body: "PureMac asks for Full Disk Access only so it can scan your protected folders. You can decline — partial results will still work.")
                }
                .padding(28)
            }
            Divider().background(Color.white.opacity(0.08))
            HStack {
                Spacer()
                Button("Get Started") {
                    UserDefaults.standard.set(true, forKey: Self.onboardingShownKey)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent).controlSize(.large).tint(.blue)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
        }
        .frame(width: 560, height: 540)
        .background(Color(red: 0.09, green: 0.09, blue: 0.14))
        .foregroundStyle(.white)
    }

    static let onboardingShownKey = "com.yakupbulbul.PureMac.onboardingShown"
    static var hasShown: Bool {
        UserDefaults.standard.bool(forKey: onboardingShownKey)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(LinearGradient(colors: [.blue, .purple],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing))
            Text("Welcome to PureMac").font(.title.bold())
            Text("A safe, transparent way to clean your Mac.")
                .font(.title3).foregroundStyle(.white.opacity(0.7))
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
                    .foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
