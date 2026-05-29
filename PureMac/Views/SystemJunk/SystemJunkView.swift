import SwiftUI

struct SystemJunkView: View {
    @Environment(SystemJunkViewModel.self) private var vm
    @Environment(CleanupCoordinator.self) private var coord

    var body: some View {
        VStack(spacing: 0) {
            FeatureToolbar(title: "System Junk", subtitle: "Caches, logs, language files, downloads") {
                toolbarButtons
            }
            Divider().background(Theme.divider)
            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.2), value: vm.isScanning)
        }
        .background(Theme.background)
        .foregroundStyle(Theme.textPrimary)
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var toolbarButtons: some View {
        switch vm.state {
        case .scanning:
            ProgressView().controlSize(.small).tint(Theme.systemJunkAccent)
        case .results:
            HStack(spacing: 8) {
                Button("Reset Defaults") { vm.resetToDefaults() }
                    .buttonStyle(.bordered).controlSize(.small).foregroundStyle(Theme.textPrimary)
                Button("Re-Scan") { vm.scan() }
                    .buttonStyle(.bordered).controlSize(.small).foregroundStyle(Theme.textPrimary)
            }
        default:
            Button("Scan") { vm.scan() }
                .buttonStyle(.borderedProminent).tint(Theme.systemJunkAccent)
        }
    }

    // MARK: - Main

    @ViewBuilder
    private var mainContent: some View {
        switch vm.state {
        case .idle:
            idleView
        case .scanning:
            loadingView
        case .results:
            resultsView
        case .error(let msg):
            ContentUnavailableView("Scan Failed",
                                   systemImage: "exclamationmark.triangle.fill",
                                   description: Text(msg))
                .foregroundStyle(Theme.textPrimary)
        }
    }

    // MARK: - States

    private var idleView: some View {
        VStack(spacing: 28) {
            Image(systemName: "arrow.3.trianglepath")
                .font(.system(size: 76))
                .foregroundStyle(LinearGradient(colors: [Theme.systemJunkAccent, Theme.appUninstallerAccent],
                                                startPoint: .top, endPoint: .bottom))
                .symbolEffect(.pulse)
            VStack(spacing: 8) {
                Text("Clean System Junk").font(.title.bold())
                Text("Scan for caches, logs, language files, and old downloads.\nNothing is removed without your review.")
                    .font(.body).foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Button("Scan for Junk") { vm.scan() }
                .buttonStyle(.borderedProminent).controlSize(.large).tint(Theme.systemJunkAccent)
        }
        .padding(40)
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView().controlSize(.extraLarge).tint(Theme.systemJunkAccent)
            VStack(spacing: 6) {
                Text("Scanning your Mac…").font(.headline)
                Text("Checking caches, logs, language files, and downloads.")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
    }

    @ViewBuilder
    private var resultsView: some View {
        if vm.categories.isEmpty {
            ContentUnavailableView("Your Mac is Clean!",
                                   systemImage: "checkmark.circle.fill",
                                   description: Text("No junk files found."))
                .foregroundStyle(Theme.textPrimary)
        } else {
            VStack(spacing: 0) {
                if vm.metadata.hasInaccessiblePaths {
                    inaccessibleBanner
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

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(vm.totalSelectedCount) item\(vm.totalSelectedCount == 1 ? "" : "s") selected")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
                HStack(spacing: 6) {
                    Text(vm.totalSelectedSize.formattedBytes)
                        .font(.headline).foregroundStyle(Theme.systemJunkAccent)
                    if vm.hasAnyRiskySelected {
                        Label("contains risky items", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(Theme.appUninstallerAccent)
                    }
                }
            }
            Spacer()
            Button("Review & Clean \(vm.totalSelectedSize.compactBytes)") {
                coord.startReview(vm.categories, title: "Review System Junk") {
                    vm.scan()   // refresh after coordinator cleanup completes
                }
            }
            .buttonStyle(.borderedProminent).tint(Theme.systemJunkAccent)
            .disabled(vm.totalSelectedSize == 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Theme.background)
    }

    private var inaccessibleBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill").foregroundStyle(Theme.fdaBannerAccent)
            Text("\(vm.metadata.inaccessibleCount) folder\(vm.metadata.inaccessibleCount == 1 ? " was" : "s were") inaccessible — grant Full Disk Access for complete results.")
                .font(.caption).foregroundStyle(Theme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Theme.fdaBannerBackground)
    }
}
