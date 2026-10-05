import SwiftUI

struct OrphanedDataView: View {
    let vm: ModuleScanViewModel

    var body: some View {
        ModuleScanView(
            vm: vm,
            title: "Leftovers",
            subtitle: "Data of apps you already removed",
            icon: "archivebox",
            accent: Theme.appUninstallerAccent,
            idleHeadline: "Find Leftovers of Removed Apps",
            idleDescription: "Looks in your Library for preferences, caches and containers\nwhose app is no longer installed. Nothing is pre-selected.",
            scanButtonTitle: "Scan for Leftovers",
            emptyTitle: "No Leftovers Found",
            emptyDescription: "Every item in your Library belongs to an installed app.",
            reviewTitle: String(localized: "Review Leftovers")
        ) {
            EmptyView()
        }
    }
}
