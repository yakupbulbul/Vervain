import SwiftUI

struct ContentView: View {
    @State private var selectedFeature: AppFeature? = .smartScan

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            SidebarView(selectedFeature: $selectedFeature)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            ZStack {
                Color(red: 0.09, green: 0.09, blue: 0.14)
                    .ignoresSafeArea()
                detailView(for: selectedFeature)
                    .frame(minWidth: 600, minHeight: 500)
            }
        }
        .navigationSplitViewStyle(.prominentDetail)
    }

    @ViewBuilder
    private func detailView(for feature: AppFeature?) -> some View {
        switch feature {
        case .smartScan, nil:   SmartScanView()
        case .systemJunk:       SystemJunkView()
        case .appUninstaller:   AppUninstallerView()
        case .diskAnalyzer:     DiskAnalyzerView()
        }
    }
}
