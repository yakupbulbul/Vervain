import SwiftUI

struct ContentView: View {
    @Binding var showAbout: Bool
    @Environment(NavigationModel.self) private var nav
    @Environment(SmartScanViewModel.self) private var smartScanVM
    @Environment(SystemJunkViewModel.self) private var systemJunkVM
    @Environment(AppUninstallerViewModel.self) private var appUninstallerVM
    @Environment(DiskAnalyzerViewModel.self) private var diskAnalyzerVM
    @Environment(LoginItemsViewModel.self) private var loginItemsVM
    @Environment(FullDiskAccessViewModel.self) private var fda
    @Environment(ModuleScanStore.self) private var modules

    var body: some View {
        @Bindable var nav = nav
        return NavigationSplitView(columnVisibility: .constant(.all)) {
            SidebarView(selectedFeature: $nav.selected, showAbout: $showAbout)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            ZStack {
                Theme.background
                    .ignoresSafeArea()
                VStack(spacing: 0) {
                    FullDiskAccessBanner()
                        .animation(.easeInOut(duration: 0.25), value: fda.shouldShowBanner)
                    detailView(for: nav.selected)
                        .frame(minWidth: 600, minHeight: 500)
                }
            }
        }
        .navigationSplitViewStyle(.prominentDetail)
        .onChange(of: nav.rescanTick) { _, _ in rescanCurrentModule() }
        .toolbar(removing: .sidebarToggle)
        .onAppear {
            // Force-hide any toolbar the system adds (sidebar toggle)
            DispatchQueue.main.async {
                for window in NSApplication.shared.windows {
                    window.toolbar?.isVisible = false
                }
            }
        }
    }

    /// ⌘R: run the visible module's scan again.
    private func rescanCurrentModule() {
        switch nav.selected {
        case .smartScan, nil:    smartScanVM.startScan()
        case .systemJunk:        systemJunkVM.scan()
        case .appUninstaller:    appUninstallerVM.scan()
        case .diskAnalyzer:      diskAnalyzerVM.analyze()
        case .largeOldFiles:     modules.largeFiles.scan()
        case .duplicates:        modules.duplicates.scan()
        case .privacy:           modules.privacy.scan()
        case .loginItems:        loginItemsVM.scan()
        case .orphanedData:      modules.orphans.scan()
        case .history:           break
        }
    }

    @ViewBuilder
    private func detailView(for feature: AppFeature?) -> some View {
        switch feature {
        case .smartScan, nil:
            SmartScanView(onNavigate: { feature in
                nav.selected = feature
            })
        case .systemJunk:
            SystemJunkView()
        case .appUninstaller:
            AppUninstallerView()
        case .diskAnalyzer:
            DiskAnalyzerView()
        case .largeOldFiles:
            LargeFilesView(vm: modules.largeFiles)
        case .duplicates:
            DuplicatesView(vm: modules.duplicates)
        case .privacy:
            PrivacyView(vm: modules.privacy)
        case .loginItems:
            LoginItemsView()
        case .history:
            HistoryView()
        case .orphanedData:
            OrphanedDataView(vm: modules.orphans)
        }
    }
}
