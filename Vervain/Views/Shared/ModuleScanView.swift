import SwiftUI

/// Standard screen for scan-then-review modules: idle → scanning → results,
/// with a bottom bar that hands the selection to the universal review flow.
struct ModuleScanView<Options: View>: View {
    let vm: ModuleScanViewModel
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let icon: String
    let accent: Color
    let idleHeadline: LocalizedStringKey
    let idleDescription: LocalizedStringKey
    let scanButtonTitle: LocalizedStringKey
    let emptyTitle: LocalizedStringKey
    let emptyDescription: LocalizedStringKey
    let reviewTitle: String
    let options: () -> Options

    @Environment(CleanupCoordinator.self) private var coord

    init(
        vm: ModuleScanViewModel,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        icon: String,
        accent: Color,
        idleHeadline: LocalizedStringKey,
        idleDescription: LocalizedStringKey,
        scanButtonTitle: LocalizedStringKey,
        emptyTitle: LocalizedStringKey,
        emptyDescription: LocalizedStringKey,
        reviewTitle: String,
        @ViewBuilder options: @escaping () -> Options
    ) {
        self.vm = vm
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.accent = accent
        self.idleHeadline = idleHeadline
        self.idleDescription = idleDescription
        self.scanButtonTitle = scanButtonTitle
        self.emptyTitle = emptyTitle
        self.emptyDescription = emptyDescription
        self.reviewTitle = reviewTitle
        self.options = options
    }

    var body: some View {
        VStack(spacing: 0) {
            FeatureToolbar(title: title, subtitle: subtitle) { toolbarButtons }
            Divider().background(Theme.divider)
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.background)
        .foregroundStyle(Theme.textPrimary)
    }

    @ViewBuilder
    private var toolbarButtons: some View {
        switch vm.state {
        case .scanning:
            ProgressView().controlSize(.small).tint(accent)
        case .results:
            Button("Re-Scan") { vm.scan() }
                .buttonStyle(.bordered).controlSize(.small).foregroundStyle(Theme.textPrimary)
        default:
            Button(scanButtonTitle) { vm.scan() }
                .buttonStyle(.borderedProminent).tint(accent)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.state {
        case .idle:
            VStack(spacing: 24) {
                Image(systemName: icon).font(.system(size: 64)).foregroundStyle(accent)
                VStack(spacing: 8) {
                    Text(idleHeadline).font(.title.bold())
                    Text(idleDescription)
                        .font(.body).foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                options()
                Button(scanButtonTitle) { vm.scan() }
                    .buttonStyle(.borderedProminent).controlSize(.large).tint(accent)
            }
            .padding(40)
        case .scanning:
            VStack(spacing: 16) {
                ProgressView().controlSize(.extraLarge).tint(accent)
                Text("Scanning your Mac…").font(.headline)
            }
            .padding(40)
        case .results:
            results
        case .error(let message):
            ContentUnavailableView("Scan Failed",
                                   systemImage: "exclamationmark.triangle.fill",
                                   description: Text(message))
        }
    }

    @ViewBuilder
    private var results: some View {
        if vm.categories.isEmpty {
            ContentUnavailableView(emptyTitle,
                                   systemImage: "checkmark.circle.fill",
                                   description: Text(emptyDescription))
        } else {
            VStack(spacing: 0) {
                if vm.metadata.hasInaccessiblePaths {
                    HStack(spacing: 10) {
                        Image(systemName: "lock.fill").foregroundStyle(Theme.fdaBannerAccent)
                        Text("\(vm.metadata.inaccessibleCount) folders were inaccessible — grant Full Disk Access for complete results.")
                            .font(.caption).foregroundStyle(Theme.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Theme.fdaBannerBackground)
                }
                List(vm.categories) { cat in
                    JunkCategoryRow(category: cat) { vm.toggleCategory(cat.id) }
                        .listRowBackground(Theme.surfaceOverlay)
                        .listRowSeparatorTint(Theme.divider)
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)

                Divider().background(Theme.divider)
                bottomBar
            }
        }
    }

    private var bottomBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(vm.totalSelectedCount) items selected")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
                Text(vm.totalSelectedSize.formattedBytes)
                    .font(.headline).foregroundStyle(accent)
            }
            Spacer()
            Button("Review & Clean \(vm.totalSelectedSize.compactBytes)") {
                coord.startReview(vm.categories, title: reviewTitle) { vm.scan() }
            }
            .buttonStyle(.borderedProminent).tint(accent)
            .disabled(vm.totalSelectedSize == 0)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(Theme.background)
    }
}
