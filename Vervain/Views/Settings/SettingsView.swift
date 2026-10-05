import SwiftUI

struct SettingsView: View {
    @AppStorage("appLanguage") private var appLanguage: String = ""
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = false
    @AppStorage("weeklyReminder") private var weeklyReminder = false
    @State private var needsRestart = false
    @State private var exclusions = ExclusionList.paths()
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

            Section("Reminders") {
                Toggle("Remind me every Monday to run a scan", isOn: $weeklyReminder)
                    .onChange(of: weeklyReminder) { _, enabled in
                        Task {
                            let ok = await ReminderScheduler.setEnabled(enabled)
                            if !ok { weeklyReminder = false }
                        }
                    }
            }

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
                Text("Vervain never offers files in these folders for cleanup.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
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
