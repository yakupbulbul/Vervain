import SwiftUI

struct DuplicatesView: View {
    let vm: ModuleScanViewModel

    @AppStorage(DuplicateKeepRule.defaultsKey) private var keepRule = DuplicateKeepRule.oldest.rawValue

    var body: some View {
        ModuleScanView(
            vm: vm,
            title: "Duplicates",
            subtitle: "Identical files taking up space twice",
            icon: "square.on.square",
            accent: Theme.duplicatesAccent,
            idleHeadline: "Find Duplicate Files",
            idleDescription: "Compares files of 1 MB or more in your personal folders.\nOne copy of every file is always kept.",
            scanButtonTitle: "Scan for Duplicates",
            emptyTitle: "No Duplicates Found",
            emptyDescription: "No identical files of 1 MB or more were found.",
            reviewTitle: String(localized: "Review Duplicates")
        ) {
            Picker("Which copy to keep", selection: $keepRule) {
                ForEach(DuplicateKeepRule.allCases) { Text($0.label).tag($0.rawValue) }
            }
            .frame(maxWidth: 420)
        }
    }
}
