import SwiftUI

struct ContentView: View {
    @Binding var showAbout: Bool
    @State private var selectedFeature: AppFeature? = .smartScan
    @Environment(FullDiskAccessViewModel.self) private var fda
    @Environment(ModuleScanStore.self) private var modules

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            SidebarView(selectedFeature: $selectedFeature, showAbout: $showAbout)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            ZStack {
                Theme.background
                    .ignoresSafeArea()
                VStack(spacing: 0) {
                    FullDiskAccessBanner()
                        .animation(.easeInOut(duration: 0.25), value: fda.shouldShowBanner)
                    detailView(for: selectedFeature)
                        .frame(minWidth: 600, minHeight: 500)
                }
            }
        }
        .navigationSplitViewStyle(.prominentDetail)
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

    @ViewBuilder
    private func detailView(for feature: AppFeature?) -> some View {
        switch feature {
        case .smartScan, nil:
            SmartScanView(onNavigate: { feature in
                selectedFeature = feature
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
        }
    }
}
