import SwiftUI

struct SettingsView: View {
    @AppStorage("appLanguage") private var appLanguage: String = ""
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = false
    @AppStorage("weeklyReminder") private var weeklyReminder = false
    @AppStorage(ReminderSchedule.weekdayKey) private var reminderWeekday = ReminderSchedule.standard.weekday
    @AppStorage(ReminderSchedule.hourKey) private var reminderHour = ReminderSchedule.standard.hour
    @AppStorage(LowDiskPolicy.enabledKey) private var lowDiskAlert = false
    @AppStorage(LowDiskPolicy.thresholdKey) private var lowDiskThreshold = LowDiskPolicy.defaultThreshold
    @AppStorage("scanOnLaunch") private var scanOnLaunch = false
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @AppStorage(CleanupCoordinator.alwaysConfirmKey) private var alwaysConfirm = false
    @State private var fda = FullDiskAccessViewModel()
    @State private var needsRestart = false
    @State private var exclusions = ExclusionList.paths()
    @State private var extraRoots = ScanRoots.extras()
    @State private var updateOutcome: UpdateChecker.Outcome?
    @State private var isCheckingForUpdates = false

    var body: some View {
        Form {
            Section("General") {
                Picker("Language", selection: $appLanguage) {
                    Text("System Default").tag("")
                    Divider()
                    Text("English").tag("en")
                    Text("Français").tag("fr")
                    Text("Deutsch").tag("de")
                    Text("Türkçe").tag("tr")
                    Text("Español").tag("es")
                    Text("中文(简体)").tag("zh-Hans")
                }
                .onChange(of: appLanguage) { _, newValue in
                    if newValue.isEmpty {
                        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
                    } else {
                        UserDefaults.standard.set([newValue], forKey: "AppleLanguages")
                    }
                    needsRestart = true
                }

                if needsRestart {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .foregroundStyle(.orange)
                        Text("Restart Vervain to apply the new language.")
                            .font(.callout)
                        Spacer()
                        Button("Restart Now") {
                            restartApp()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                }
            }

            Section("Menu Bar") {
                Toggle("Show disk usage in the menu bar", isOn: $showMenuBarExtra)
            }

            Section {
                HStack {
                    Image(systemName: fda.status == .likelyGranted ? "checkmark.circle.fill" : "exclamationmark.circle")
                        .foregroundStyle(fda.status == .likelyGranted ? Color.green : Color.orange)
                    Text(fda.status == .likelyGranted
                         ? "Full Disk Access appears granted"
                         : "Full Disk Access is not granted yet")
                    Spacer()
                    Button("Open System Settings") { fda.openSystemSettings() }
                }
                Toggle("Always ask me to confirm before cleaning", isOn: $alwaysConfirm)
                Button("Show Welcome Tour Again") {
                    NotificationCenter.default.post(name: OnboardingView.replayNotification, object: nil)
                }
            } header: {
                Text("Safety")
            } footer: {
                Text("Items marked risky or review always need confirmation.")
            }

            Section("Startup") {
                Toggle("Open Vervain when I log in", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            try LaunchAtLogin.set(enabled)
                        } catch {
                            launchAtLogin = LaunchAtLogin.isEnabled
                        }
                    }
                Toggle("Run a Smart Scan when Vervain opens", isOn: $scanOnLaunch)
            }

            Section {
                Toggle("Remind me weekly to run a scan", isOn: $weeklyReminder)
                    .onChange(of: weeklyReminder) { _, enabled in
                        Task {
                            let ok = await ReminderScheduler.setEnabled(enabled)
                            if !ok { weeklyReminder = false }
                        }
                    }
                if weeklyReminder {
                    Picker("Day", selection: $reminderWeekday) {
                        ForEach(1...7, id: \.self) { day in
                            Text(Calendar.current.weekdaySymbols[day - 1]).tag(day)
                        }
                    }
                    Picker("Time", selection: $reminderHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%02d:00", hour)).tag(hour)
                        }
                    }
                }
                Toggle("Warn me when the disk is almost full", isOn: $lowDiskAlert)
                    .onChange(of: lowDiskAlert) { _, enabled in
                        guard enabled else { return }
                        Task {
                            if !(await ReminderScheduler.requestAuthorization()) { lowDiskAlert = false }
                        }
                    }
                if lowDiskAlert {
                    Picker("Warn at", selection: $lowDiskThreshold) {
                        ForEach([80, 85, 90, 95], id: \.self) { Text("\($0)% full").tag($0) }
                    }
                }
            } header: {
                Text("Reminders")
            } footer: {
                Text("Notifications are local. The disk check only runs while Vervain is open.")
            }
            .onChange(of: reminderWeekday) { _, _ in rescheduleReminder() }
            .onChange(of: reminderHour) { _, _ in rescheduleReminder() }

            Section {
                HStack {
                    Button("Check for Updates…") { checkForUpdates() }
                        .disabled(isCheckingForUpdates)
                    if isCheckingForUpdates { ProgressView().controlSize(.small) }
                    Spacer()
                    updateStatus
                }
            } header: {
                Text("Updates")
            } footer: {
                Text("Vervain only contacts the network when you press this button.")
            }

            Section {
                ForEach(extraRoots, id: \.self) { path in
                    HStack {
                        Text(CleanupItem.makeDisplayPath(url: URL(fileURLWithPath: path)))
                            .lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Button {
                            ScanRoots.remove(path)
                            extraRoots = ScanRoots.extras()
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Stop scanning this folder")
                    }
                }
                Button("Add Folder…") { chooseScanFolders() }
            } header: {
                Text("Extra Folders to Scan")
            } footer: {
                Text("Large & Old Files and Duplicates also look in these folders, next to Downloads, Documents, Desktop, Movies, Music and Pictures.")
            }

            Section {
                if exclusions.isEmpty {
                    Text("Nothing is excluded.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                ForEach(exclusions, id: \.self) { path in
                    HStack {
                        Text(CleanupItem.makeDisplayPath(url: URL(fileURLWithPath: path)))
                            .lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Button {
                            ExclusionList.remove(path)
                            exclusions = ExclusionList.paths()
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Stop excluding this folder")
                    }
                }
                Button("Add Folder…") { chooseFolders() }
            } header: {
                Text("Excluded Folders")
            } footer: {
                Text("Vervain never offers files in these folders for cleanup. You can also drop folders here.")
            }
            .dropDestination(for: URL.self) { urls, _ in
                for url in urls { ExclusionList.add(url.path) }
                exclusions = ExclusionList.paths()
                return !urls.isEmpty
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, minHeight: 420, maxHeight: 700)
        .task { fda.refresh() }
    }

    @ViewBuilder
    private var updateStatus: some View {
        switch updateOutcome {
        case .upToDate:
            Text("You are up to date.").font(.callout).foregroundStyle(.secondary)
        case .available(let version, let url):
            Link("Version \(version) is available", destination: url).font(.callout)
        case .failed:
            Text("Could not check for updates.").font(.callout).foregroundStyle(.secondary)
        case nil:
            EmptyView()
        }
    }

    private func checkForUpdates() {
        isCheckingForUpdates = true
        updateOutcome = nil
        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        Task {
            let outcome = await UpdateChecker.check(current: current)
            updateOutcome = outcome
            isCheckingForUpdates = false
        }
    }

    private func rescheduleReminder() {
        guard weeklyReminder else { return }
        Task { _ = await ReminderScheduler.setEnabled(true) }
    }

    private func chooseScanFolders() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = String(localized: "Scan")
        guard panel.runModal() == .OK else { return }
        for url in panel.urls { ScanRoots.add(url.path) }
        extraRoots = ScanRoots.extras()
    }

    private func chooseFolders() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = String(localized: "Exclude")
        guard panel.runModal() == .OK else { return }
        for url in panel.urls { ExclusionList.add(url.path) }
        exclusions = ExclusionList.paths()
    }

    private func restartApp() {
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config) { _, _ in
            DispatchQueue.main.async { NSApplication.shared.terminate(nil) }
        }
    }
}
