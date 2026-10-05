import SwiftUI

@main
struct VervainApp: App {

    @State private var smartScanVM      = SmartScanViewModel()
    @State private var systemJunkVM     = SystemJunkViewModel()
    @State private var appUninstallerVM = AppUninstallerViewModel()
    @State private var diskAnalyzerVM   = DiskAnalyzerViewModel()
    @State private var loginItemsVM     = LoginItemsViewModel()
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
                .environment(cleanupCoord)
                .environment(fdaVM)
                .task { fdaVM.refresh() }
                .sheet(isPresented: $showAbout) {
                    AboutView()
                }
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView(isPresented: $showOnboarding)
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
