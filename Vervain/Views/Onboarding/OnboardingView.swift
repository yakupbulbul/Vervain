import SwiftUI

/// First-launch tour: the privacy and safety promises, an optional Full Disk
/// Access step, and optional reminders. Persisted in UserDefaults so it only
/// appears once per install; Settings can show it again.
struct OnboardingView: View {
    @Binding var isPresented: Bool

    @Environment(FullDiskAccessViewModel.self) private var fda
    @AppStorage("weeklyReminder") private var weeklyReminder = false
    @AppStorage(LowDiskPolicy.enabledKey) private var lowDiskAlert = false
    @State private var step = 0

    private static let lastStep = 2

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    switch step {
                    case 0:  promisesStep
                    case 1:  accessStep
                    default: remindersStep
                    }
                }
                .padding(28)
            }
            Divider().background(Theme.divider)
            footer
        }
        .frame(width: 560, height: 540)
        .background(Theme.background)
        .foregroundStyle(Theme.textPrimary)
    }

    static let onboardingShownKey = "com.yakupbulbul.Vervain.onboardingShown"
    static let replayNotification = Notification.Name("app.vervain.showOnboarding")
    static var hasShown: Bool {
        UserDefaults.standard.bool(forKey: onboardingShownKey)
    }

    // MARK: - Steps

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(Theme.brandGradient())
                .accessibilityHidden(true)
            Text("Welcome to Vervain").font(.title.bold())
            Text("A gentle way to care for your Mac.")
                .font(.title3).foregroundStyle(Theme.textSecondary)
        }
    }

    private var promisesStep: some View {
        VStack(alignment: .leading, spacing: 28) {
            promise(icon: "hand.raised.fill", color: Theme.smartScanAccent,
                    title: "Private by design",
                    body: "Vervain never sends data anywhere. No telemetry, no analytics, no account. Everything runs on this Mac.")
            promise(icon: "arrow.3.trianglepath", color: Theme.systemJunkAccent,
                    title: "Trash only — nothing is permanently deleted",
                    body: "Every cleanup moves files to the Trash. You can restore anything until you empty it yourself.")
            promise(icon: "eye.fill", color: Theme.statusSafe,
                    title: "Review before you clean",
                    body: "Nothing is ever removed without a review screen. Risky or low-confidence items are never selected by default.")
            promise(icon: "binoculars.fill", color: Theme.diskAnalyzerAccent,
                    title: "Optional Full Disk Access",
                    body: "Vervain asks for Full Disk Access only so it can scan your protected folders. You can decline — partial results will still work.")
        }
    }

    private var accessStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            promise(icon: "lock.open.fill", color: Theme.diskAnalyzerAccent,
                    title: "Full Disk Access",
                    body: "Without it Vervain skips protected folders such as Mail, Safari data and some caches, and tells you what it could not reach. Granting it is optional and you can change your mind in System Settings at any time.")
            HStack(spacing: 10) {
                Image(systemName: fda.status == .likelyGranted ? "checkmark.circle.fill" : "circle.dashed")
                    .foregroundStyle(fda.status == .likelyGranted ? Theme.statusSafe : Theme.textMuted)
                Text(fda.status == .likelyGranted
                     ? "Full Disk Access appears granted"
                     : "Full Disk Access is not granted yet")
                    .font(.subheadline)
            }
            Button("Open System Settings") { fda.openSystemSettings() }
                .buttonStyle(.bordered)
        }
        .task { fda.refresh(force: true) }
    }

    private var remindersStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            promise(icon: "bell.fill", color: Theme.systemJunkAccent,
                    title: "Stay on top of it (optional)",
                    body: "Vervain can send local notifications. They never leave your Mac, and you can change this later in Settings.")
            Toggle("Remind me weekly to run a scan", isOn: $weeklyReminder)
                .onChange(of: weeklyReminder) { _, enabled in
                    Task { if !(await ReminderScheduler.setEnabled(enabled)) { weeklyReminder = false } }
                }
            Toggle("Warn me when the disk is almost full", isOn: $lowDiskAlert)
                .onChange(of: lowDiskAlert) { _, enabled in
                    guard enabled else { return }
                    Task { if !(await ReminderScheduler.requestAuthorization()) { lowDiskAlert = false } }
                }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if step < Self.lastStep {
                Button("Skip Tour") { finish(scan: false) }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Button("Back") { step -= 1 }.buttonStyle(.borderless)
            }
            if step > 0 && step < Self.lastStep {
                Button("Back") { step -= 1 }.buttonStyle(.borderless)
            }
            Spacer()
            if step < Self.lastStep {
                Button("Continue") { step += 1 }
                    .buttonStyle(.borderedProminent).controlSize(.large).tint(Theme.brandPrimary)
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Get Started") { finish(scan: false) }
                    .buttonStyle(.bordered).controlSize(.large)
                Button("Scan Now") { finish(scan: true) }
                    .buttonStyle(.borderedProminent).controlSize(.large).tint(Theme.brandPrimary)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
    }

    private func finish(scan: Bool) {
        UserDefaults.standard.set(true, forKey: Self.onboardingShownKey)
        isPresented = false
        if scan {
            NotificationCenter.default.post(name: NotificationRouter.startScanNotification, object: nil)
        }
    }

    private func promise(icon: String, color: Color,
                         title: LocalizedStringKey, body: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(color.opacity(0.18)).frame(width: 36, height: 36)
                Image(systemName: icon).foregroundStyle(color)
                    .font(.system(size: 16, weight: .semibold))
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(body).font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
