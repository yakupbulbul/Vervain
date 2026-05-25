import SwiftUI

struct SystemJunkView: View {
    @Environment(SystemJunkViewModel.self) private var vm

    var body: some View {
        VStack(spacing: 0) {
            FeatureToolbar(title: "System Junk", subtitle: "Caches, logs, language files, downloads") {
                toolbarButtons
            }
            Divider().background(Color.white.opacity(0.08))
            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(red: 0.09, green: 0.09, blue: 0.14))
        .foregroundStyle(.white)
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var toolbarButtons: some View {
        switch vm.state {
        case .scanning:
            ProgressView().controlSize(.small).tint(.white)
        case .results:
            HStack(spacing: 8) {
                Button("Reset Defaults") { vm.resetToDefaults() }
                    .buttonStyle(.bordered).controlSize(.small).foregroundStyle(.white)
                Button("Re-Scan") { vm.scan() }
                    .buttonStyle(.bordered).controlSize(.small).foregroundStyle(.white)
            }
        default:
            Button("Scan") { vm.scan() }
                .buttonStyle(.borderedProminent).tint(.orange)
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
        case .cleaning:
            cleaningView
        case .done(let result):
            doneView(result)
        case .error(let msg):
            ContentUnavailableView("Scan Failed",
                                   systemImage: "exclamationmark.triangle.fill",
                                   description: Text(msg))
                .foregroundStyle(.white)
        }
    }

    // MARK: - States

    private var idleView: some View {
        VStack(spacing: 28) {
            Image(systemName: "trash.circle.fill")
                .font(.system(size: 76))
                .foregroundStyle(LinearGradient(colors: [.orange, .red],
                                                startPoint: .top, endPoint: .bottom))
                .symbolEffect(.pulse)
            VStack(spacing: 8) {
                Text("Clean System Junk").font(.title.bold())
                Text("Scan for caches, logs, language files, and old downloads.\nNothing is removed without your review.")
                    .font(.body).foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }
            Button("Scan for Junk") { vm.scan() }
                .buttonStyle(.borderedProminent).controlSize(.large).tint(.orange)
        }
        .padding(40)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large).tint(.orange)
            Text("Scanning…").foregroundStyle(.white.opacity(0.6))
        }
    }

    @ViewBuilder
    private var resultsView: some View {
        if vm.categories.isEmpty {
            ContentUnavailableView("Your Mac is Clean!",
                                   systemImage: "checkmark.circle.fill",
                                   description: Text("No junk files found."))
                .foregroundStyle(.white)
        } else {
            VStack(spacing: 0) {
                if vm.metadata.hasInaccessiblePaths {
                    inaccessibleBanner
                }
                List(vm.categories) { cat in
                    JunkCategoryRow(category: cat) { vm.toggleCategory(cat.id) }
                        .listRowBackground(Color.white.opacity(0.04))
                        .listRowSeparatorTint(Color.white.opacity(0.07))
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)

                Divider().background(Color.white.opacity(0.08))
                bottomBar
            }
        }
    }

    private var cleaningView: some View {
        VStack(spacing: 24) {
            ProgressView(value: vm.progress?.fraction ?? 0)
                .progressViewStyle(.linear).tint(.orange)
                .frame(width: 360)
            VStack(spacing: 4) {
                Text("Cleaning…").font(.title3.bold())
                if let p = vm.progress {
                    Text("\(p.currentIndex) of \(p.totalCount) · \(p.bytesFreed.formattedBytes) freed")
                        .font(.caption).foregroundStyle(.white.opacity(0.5))
                }
            }
        }
    }

    private func doneView(_ result: CleanupResult) -> some View {
        VStack(spacing: 20) {
            Image(systemName: result.allSucceeded ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(result.allSucceeded ? .green : .yellow)
            Text(result.allSucceeded ? "Cleanup Complete" : "Completed with Issues")
                .font(.title2.bold())
            Text("\(result.freedBytes.formattedBytes) freed · moved \(result.successCount) item\(result.successCount == 1 ? "" : "s") to Trash")
                .foregroundStyle(.white.opacity(0.7))
            if result.failedCount > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(result.failedCount) item\(result.failedCount == 1 ? "" : "s") could not be removed:")
                        .font(.caption.bold()).foregroundStyle(.yellow)
                    ForEach(result.failures.prefix(5)) { f in
                        Text("• \(f.item.name) — \(f.reason.displayText)")
                            .font(.caption2).foregroundStyle(.white.opacity(0.6))
                    }
                    if result.failures.count > 5 {
                        Text("and \(result.failures.count - 5) more…").font(.caption2).foregroundStyle(.white.opacity(0.4))
                    }
                }
                .padding(.horizontal, 40)
            }
            HStack(spacing: 12) {
                Button("Open Trash") { openTrash() }
                    .buttonStyle(.bordered).controlSize(.large).foregroundStyle(.white)
                Button("Done") { vm.dismissResult() }
                    .buttonStyle(.borderedProminent).controlSize(.large).tint(.orange)
            }
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(vm.totalSelectedCount) item\(vm.totalSelectedCount == 1 ? "" : "s") selected")
                    .font(.caption).foregroundStyle(.white.opacity(0.5))
                HStack(spacing: 6) {
                    Text(vm.totalSelectedSize.formattedBytes)
                        .font(.headline).foregroundStyle(.orange)
                    if vm.hasAnyRiskySelected {
                        Label("contains risky items", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.red)
                    }
                }
            }
            Spacer()
            Button("Clean \(vm.totalSelectedSize.compactBytes)") { vm.clean() }
                .buttonStyle(.borderedProminent).tint(.orange)
                .disabled(vm.totalSelectedSize == 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(red: 0.09, green: 0.09, blue: 0.14))
    }

    private var inaccessibleBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill").foregroundStyle(.yellow)
            Text("\(vm.metadata.inaccessibleCount) folder\(vm.metadata.inaccessibleCount == 1 ? " was" : "s were") inaccessible — grant Full Disk Access for complete results.")
                .font(.caption).foregroundStyle(.white.opacity(0.7))
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Color.yellow.opacity(0.08))
    }

    private func openTrash() {
        let trash = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".Trash")
        NSWorkspace.shared.open(trash)
    }
}
