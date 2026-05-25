import SwiftUI

@main
struct PureMacApp: App {

    @State private var smartScanVM      = SmartScanViewModel()
    @State private var systemJunkVM     = SystemJunkViewModel()
    @State private var appUninstallerVM = AppUninstallerViewModel()
    @State private var diskAnalyzerVM   = DiskAnalyzerViewModel()
    @State private var cleanupCoord     = CleanupCoordinator()
    @State private var fdaVM            = FullDiskAccessViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(smartScanVM)
                .environment(systemJunkVM)
                .environment(appUninstallerVM)
                .environment(diskAnalyzerVM)
                .environment(cleanupCoord)
                .environment(fdaVM)
                .task { fdaVM.refresh() }
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
        }
    }
}
