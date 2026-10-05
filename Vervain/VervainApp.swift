import SwiftUI
import UserNotifications

@main
struct VervainApp: App {

    @State private var smartScanVM      = SmartScanViewModel()
    @State private var systemJunkVM     = SystemJunkViewModel()
    @State private var appUninstallerVM = AppUninstallerViewModel()
    @State private var diskAnalyzerVM   = DiskAnalyzerViewModel()
    @State private var loginItemsVM     = LoginItemsViewModel()
    @State private var moduleStore      = ModuleScanStore()
    @State private var historyVM        = HistoryViewModel()
    @State private var nav              = NavigationModel()
    @State private var cleanupCoord     = CleanupCoordinator()
    @State private var fdaVM            = FullDiskAccessViewModel()
    @State private var showOnboarding   = !OnboardingView.hasShown
    @State private var showAbout        = false
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = false
    var body: some Scene {
        WindowGroup {
            ContentView(showAbout: $showAbout)
                .environment(smartScanVM)
                .environment(systemJunkVM)
                .environment(appUninstallerVM)
                .environment(diskAnalyzerVM)
                .environment(loginItemsVM)
                .environment(moduleStore)
                .environment(historyVM)
                .environment(nav)
                .environment(cleanupCoord)
                .environment(fdaVM)
                .task {
                    fdaVM.refresh()
                    UNUserNotificationCenter.current().delegate = NotificationRouter.shared
                    DiskMonitor.shared.start()
                    if UserDefaults.standard.bool(forKey: "scanOnLaunch") { smartScanVM.startScan() }
                }
                .onReceive(NotificationCenter.default.publisher(for: OnboardingView.replayNotification)) { _ in
                    showOnboarding = true
                }
                .sheet(isPresented: $showAbout) {
                    AboutView()
                }
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView(isPresented: $showOnboarding)
                        .environment(fdaVM)
                }
                .sheet(isPresented: Binding(
                    get: { cleanupCoord.isReviewPresented },
                    set: { cleanupCoord.isReviewPresented = $0 }
                )) {
                    CleanupReviewView()
                        .environment(cleanupCoord)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 980, height: 660)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .appInfo) {
                Button("About Vervain") { showAbout = true }
            }
            CommandGroup(after: .help) {
                Button("Welcome Tour") {
                    NotificationCenter.default.post(name: OnboardingView.replayNotification, object: nil)
                }
            }
            CommandMenu("Go") {
                ForEach(Array(AppFeature.allCases.prefix(9).enumerated()), id: \.element) { index, feature in
                    Button(feature.displayName) { nav.selected = feature }
                        .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
                }
                Divider()
                Button("Rescan") { nav.requestRescan() }
                    .keyboardShortcut("r", modifiers: .command)
            }
        }

        MenuBarExtra("Vervain", systemImage: "leaf.fill", isInserted: $showMenuBarExtra) {
            MenuBarContentView()
                .environment(systemJunkVM)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}
