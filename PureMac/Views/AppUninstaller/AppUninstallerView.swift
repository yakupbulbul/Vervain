import SwiftUI

struct AppUninstallerView: View {
    @Environment(AppUninstallerViewModel.self) private var vm
    @Environment(CleanupCoordinator.self) private var coord

    @State private var searchText: String = ""
    @State private var selectedDetailID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            FeatureToolbar(title: "App Uninstaller",
                           subtitle: "Remove apps and their leftovers safely") {
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
            Button("Re-Scan") { vm.scan() }
                .buttonStyle(.bordered).controlSize(.small).foregroundStyle(.white)
        default:
            Button("Scan Apps") { vm.scan() }
                .buttonStyle(.borderedProminent).tint(.red)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var mainContent: some View {
        switch vm.state {
        case .idle:
            idleView
        case .scanning:
            loadingView
        case .results:
            if vm.apps.isEmpty {
                ContentUnavailableView("No Apps Found",
                                       systemImage: "app.badge.minus",
                                       description: Text("Nothing found in /Applications, ~/Applications, or /Applications/Utilities."))
                    .foregroundStyle(.white)
            } else {
                splitView
            }
        }
    }

    private var idleView: some View {
        VStack(spacing: 28) {
            Image(systemName: "app.badge.minus")
                .font(.system(size: 76))
                .foregroundStyle(LinearGradient(colors: [.red, .pink],
                                                startPoint: .top, endPoint: .bottom))
                .symbolEffect(.pulse)
            VStack(spacing: 8) {
                Text("Remove Apps Completely").font(.title.bold())
                Text("Find installed apps with confidence-graded leftover\ndetection. Apple system apps are protected.")
                    .font(.body).foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }
            Button("Scan Applications") { vm.scan() }
                .buttonStyle(.borderedProminent).controlSize(.large).tint(.red)
        }
        .padding(40)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large).tint(.red)
            Text("Scanning installed apps…").foregroundStyle(.white.opacity(0.6))
        }
    }

    // MARK: - Split layout

    private var splitView: some View {
        HSplitView {
            appListPane
                .frame(minWidth: 320)
            detailPane
                .frame(minWidth: 320)
        }
    }

    private var appListPane: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.4))
                TextField("Search apps…", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color.white.opacity(0.06))

            List(selection: $selectedDetailID) {
                ForEach(filteredApps) { app in
                    AppRow(
                        app: app,
                        isSelected: vm.selectedIDs.contains(app.id),
                        isScanningLeftovers: vm.scanningLeftoversID == app.id,
                        onToggle: { vm.toggleSelection(app.id) },
                        onScanLeftovers: { vm.scanLeftovers(for: app) }
                    )
                    .tag(app.id)
                    .listRowBackground(
                        vm.selectedIDs.contains(app.id)
                            ? Color.red.opacity(0.10)
                            : Color.white.opacity(0.04)
                    )
                    .listRowSeparatorTint(Color.white.opacity(0.06))
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)

            if !vm.selectedIDs.isEmpty {
                uninstallBar
            }
        }
    }

    private var filteredApps: [AppInfo] {
        let q = searchText.lowercased()
        if q.isEmpty { return vm.apps }
        return vm.apps.filter {
            $0.name.lowercased().contains(q) || $0.bundleID.lowercased().contains(q)
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let id = selectedDetailID, let app = vm.apps.first(where: { $0.id == id }) {
            AppDetailPanel(
                app: app,
                isScanningLeftovers: vm.scanningLeftoversID == app.id,
                onScanLeftovers: { vm.scanLeftovers(for: app) }
            )
        } else {
            ContentUnavailableView("Select an app",
                                   systemImage: "app.dashed",
                                   description: Text("Pick an app from the list to see details."))
                .foregroundStyle(.white)
        }
    }

    private var uninstallBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(vm.selectedIDs.count) app\(vm.selectedIDs.count == 1 ? "" : "s") selected")
                    .font(.caption).foregroundStyle(.white.opacity(0.5))
                Text(vm.totalSelectedSize.formattedBytes)
                    .font(.headline).foregroundStyle(.red)
            }
            Spacer()
            Button("Review & Uninstall") {
                coord.startReview(
                    vm.buildCleanupCategories(),
                    title: "Review Uninstall"
                )
            }
            .buttonStyle(.borderedProminent).tint(.red)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color(red: 0.09, green: 0.09, blue: 0.14))
    }
}

// MARK: - App Row

struct AppRow: View {
    let app: AppInfo
    let isSelected: Bool
    let isScanningLeftovers: Bool
    let onToggle: () -> Void
    let onScanLeftovers: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .red : .white.opacity(0.3))
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)

            AppIconView(appURL: app.url)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(app.name).font(.system(size: 13, weight: .semibold))
                    if let v = app.version {
                        Text(v).font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                Text(app.bundleID).font(.caption)
                    .foregroundStyle(.white.opacity(0.4)).lineLimit(1)
            }

            Spacer()

            SizeBadge(bytes: app.bundleSize, color: .blue)

            Group {
                if isScanningLeftovers {
                    ProgressView().controlSize(.mini).tint(.orange)
                        .frame(width: 70)
                } else if app.leftoverScanned {
                    if app.leftoverSize > 0 {
                        SizeBadge(bytes: app.leftoverSize, color: .orange)
                            .frame(width: 70, alignment: .trailing)
                    } else {
                        Text("Clean").font(.caption)
                            .foregroundStyle(.green.opacity(0.8))
                            .frame(width: 70, alignment: .trailing)
                    }
                } else {
                    Button("Leftovers") { onScanLeftovers() }
                        .buttonStyle(.borderless).font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 70, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
    }
}
