import SwiftUI

struct LargeFilesView: View {
    let vm: ModuleScanViewModel

    @AppStorage(LargeFilesConfig.sizeKey) private var minSizeMB = LargeFilesConfig.defaultMinSizeMB
    @AppStorage(LargeFilesConfig.ageKey) private var minAgeDays = LargeFilesConfig.defaultMinAgeDays

    var body: some View {
        ModuleScanView(
            vm: vm,
            title: "Large & Old Files",
            subtitle: "Big files you have not touched in a while",
            icon: "doc.badge.clock",
            accent: Theme.largeFilesAccent,
            idleHeadline: "Find Forgotten Giants",
            idleDescription: "Looks through Downloads, Documents, Desktop, Movies, Music and Pictures.\nNothing is removed without your review.",
            scanButtonTitle: "Scan for Large Files",
            emptyTitle: "No Large Old Files",
            emptyDescription: "Nothing matched your size and age settings.",
            reviewTitle: String(localized: "Review Large & Old Files")
        ) {
            HStack(spacing: 24) {
                Picker("Larger than", selection: $minSizeMB) {
                    ForEach([50, 100, 500, 1000], id: \.self) { mb in
                        Text("\(mb) MB").tag(mb)
                    }
                }
                Picker("Not modified for", selection: $minAgeDays) {
                    ForEach([30, 90, 180, 365], id: \.self) { days in
                        Text("\(days) days").tag(days)
                    }
                }
            }
            .frame(maxWidth: 480)
        }
    }
}
