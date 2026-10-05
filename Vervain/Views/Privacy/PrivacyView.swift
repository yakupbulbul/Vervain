import SwiftUI

struct PrivacyView: View {
    let vm: ModuleScanViewModel

    var body: some View {
        ModuleScanView(
            vm: vm,
            title: "Privacy",
            subtitle: "Browser caches, history and cookies",
            icon: "hand.raised.fill",
            accent: Theme.privacyAccent,
            idleHeadline: "Tidy Your Browsing Traces",
            idleDescription: "Finds data left by Safari, Chrome, Firefox, Edge and Brave.\nOnly caches are pre-selected. History and cookies are your call.",
            scanButtonTitle: "Scan Browsers",
            emptyTitle: "Nothing to Clean",
            emptyDescription: "No browser data was found.",
            reviewTitle: String(localized: "Review Privacy Cleanup")
        ) {
            EmptyView()
        }
    }
}
