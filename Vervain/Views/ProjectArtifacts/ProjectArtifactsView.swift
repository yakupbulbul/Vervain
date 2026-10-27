import SwiftUI

struct ProjectArtifactsView: View {
    let vm: ModuleScanViewModel

    @AppStorage(ProjectArtifactsConfig.idleKey) private var minIdleDays = ProjectArtifactsConfig.defaultMinIdleDays

    var body: some View {
        ModuleScanView(
            vm: vm,
            title: "Project Artifacts",
            subtitle: "Build folders your tools can recreate",
            icon: "shippingbox.fill",
            accent: Theme.projectArtifactsAccent,
            idleHeadline: "Clear Old Build Folders",
            idleDescription: "Finds node_modules, target, .build, Pods, virtual environments and similar folders in your projects.\nOnly git-ignored folders of idle projects are pre-selected. Everything goes to the Trash.",
            scanButtonTitle: "Scan Projects",
            emptyTitle: "No Build Folders Found",
            emptyDescription: "Nothing rebuildable was found in your project folders.",
            reviewTitle: String(localized: "Review Project Artifacts")
        ) {
            Picker("Project idle for", selection: $minIdleDays) {
                ForEach([7, 14, 30, 90], id: \.self) { days in
                    Text("\(days) days").tag(days)
                }
            }
            .frame(maxWidth: 260)
        }
    }
}
