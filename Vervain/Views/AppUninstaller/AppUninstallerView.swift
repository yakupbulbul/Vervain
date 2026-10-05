import SwiftUI

struct AppUninstallerView: View {
    @Environment(AppUninstallerViewModel.self) private var vm
    @Environment(CleanupCoordinator.self) private var coord

    @State private var searchText: String = ""
    @State private var selectedDetailID: UUID?
    @State private var sortOrder: SortOrder = .size

    enum SortOrder: String, CaseIterable {
        case size = "Size"
        case name = "Name"
        case date = "Date"
    }

    var body: some View {
        VStack(spacing: 0) {
            FeatureToolbar(title: "App Uninstaller",
                           subtitle: "Remove apps and their leftovers safely") {
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
            ProgressView().controlSize(.small).tint(Theme.appUninstallerAccent)
        case .results:
            Button("Re-Scan") { vm.scan() }
                .buttonStyle(.bordered).controlSize(.small).foregroundStyle(Theme.textPrimary)
        default:
            Button("Scan Apps") { vm.scan() }
                .buttonStyle(.borderedProminent).tint(Theme.appUninstallerAccent)
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
                                       systemImage: "xmark.app.fill",
                                       description: Text("Nothing found in /Applications, ~/Applications, or /Applications/Utilities."))
                    .foregroundStyle(Theme.textPrimary)
            } else {
                splitView
            }
        }
    }

    private var idleView: some View {
        VStack(spacing: 28) {
            Image(systemName: "leaf.arrow.circlepath")
                .font(.system(size: 76))
                .foregroundStyle(LinearGradient(colors: [Theme.appUninstallerAccent, Color(red: 0.60, green: 0.32, blue: 0.22)],
                                                startPoint: .top, endPoint: .bottom))
                .symbolEffect(.pulse)
            VStack(spacing: 8) {
                Text("Remove Apps Completely").font(.title.bold())
                Text("Find installed apps with confidence-graded leftover\ndetection. Apple system apps are protected.")
                    .font(.body).foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Button("Scan Applications") { vm.scan() }
                .buttonStyle(.borderedProminent).controlSize(.large).tint(Theme.appUninstallerAccent)
        }
        .padding(40)
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView().controlSize(.extraLarge).tint(Theme.appUninstallerAccent)
            VStack(spacing: 6) {
                Text("Scanning installed apps…").font(.headline)
                Text("Looking in /Applications and ~/Applications.")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
    }

    // MARK: - Split layout

    private var splitView: some View {
        HSplitView {
            appListPane
                .frame(minWidth: 480, idealWidth: 540)
            detailPane
                .frame(minWidth: 320)
        }
    }

    private var appListPane: some View {
        VStack(spacing: 0) {
            // Search + sort bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.textMuted)
                TextField("Search apps…", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Picker("Sort", selection: $sortOrder) {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Theme.surfaceOverlay)

            // Stats bar
            HStack(spacing: 16) {
                Text("\(filteredApps.count) apps")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
                Spacer()
                if !vm.selectedIDs.isEmpty {
                    Text("\(vm.selectedIDs.count) selected")
                        .font(.caption.bold()).foregroundStyle(Theme.appUninstallerAccent)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(Theme.surfaceOverlay)

            Divider().background(Theme.divider)

            List(filteredApps, selection: $selectedDetailID) { app in
                AppRow(
                    app: app,
                    isSelected: vm.selectedIDs.contains(app.id),
                    isDetailSelected: selectedDetailID == app.id,
                    isScanningLeftovers: vm.scanningLeftoversID == app.id,
                    onToggle: {
                        vm.toggleSelection(app.id)
                        selectedDetailID = app.id
                    },
                    onSelect: { selectedDetailID = app.id },
                    onScanLeftovers: { vm.scanLeftovers(for: app) }
                )
                .tag(app.id)
                .listRowInsets(EdgeInsets())
                .listRowBackground(
                    selectedDetailID == app.id
                        ? Theme.divider
                        : (vm.selectedIDs.contains(app.id) ? Theme.appUninstallerAccent.opacity(0.06) : Theme.background)
                )
                .listRowSeparator(.visible)
                .listRowSeparatorTint(Theme.divider)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.background)

            if !vm.selectedIDs.isEmpty {
                uninstallBar
            }
        }
    }

    private var filteredApps: [AppInfo] {
        let q = searchText.lowercased()
        let base = q.isEmpty ? vm.apps : vm.apps.filter {
            $0.name.lowercased().contains(q) || $0.bundleID.lowercased().contains(q)
        }
        switch sortOrder {
        case .size: return base.sorted { $0.bundleSize > $1.bundleSize }
        case .name: return base.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .date: return base.sorted { ($0.lastModifiedDate ?? .distantPast) > ($1.lastModifiedDate ?? .distantPast) }
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
            VStack(spacing: 16) {
                Image(systemName: "app.dashed")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.textFaint)
                Text("Select an app")
                    .font(.title3.bold()).foregroundStyle(Theme.textSecondary)
                Text("Pick an app from the list to see details.")
                    .font(.caption).foregroundStyle(Theme.textMuted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var uninstallBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(vm.selectedIDs.count) apps selected")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.textSecondary)
                Text(vm.totalSelectedSize.formattedBytes)
                    .font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(Theme.appUninstallerAccent)
            }
            Spacer()
            Button("Deselect All") {
                vm.selectedIDs.removeAll()
            }
            .buttonStyle(.bordered).controlSize(.small).foregroundStyle(Theme.textPrimary)
            Button("Review & Uninstall") {
                coord.startReview(
                    vm.buildCleanupCategories(),
                    title: String(localized: "Review Uninstall")
                ) {
                    vm.scan()
                }
            }
            .buttonStyle(.borderedProminent).tint(Theme.appUninstallerAccent)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(
            Theme.appUninstallerAccent.opacity(0.08)
                .overlay(alignment: .top) {
                    Divider().background(Theme.appUninstallerAccent.opacity(0.3))
                }
        )
    }
}

// MARK: - App Row

struct AppRow: View {
    let app: AppInfo
    let isSelected: Bool
    let isDetailSelected: Bool
    let isScanningLeftovers: Bool
    let onToggle: () -> Void
    let onSelect: () -> Void
    let onScanLeftovers: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button {
                onToggle()
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Theme.appUninstallerAccent : Theme.textFaint)
                    .font(.system(size: 20))
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSelected
                                ? String(localized: "Deselect \(app.name)")
                                : String(localized: "Select \(app.name)"))

            // App icon
            AppIconView(appURL: app.url)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 9))

            // App info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(app.name)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    if let v = app.version {
                        Text(v)
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(Theme.textMuted)
                            .lineLimit(1)
                    }
                }
                Text(app.bundleID)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Theme.textMuted)
                    .lineLimit(1)
            }

            Spacer()

            // Size badge
            Text(app.bundleSize.compactBytes)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(sizeColor(app.bundleSize).opacity(0.2), in: Capsule())

            // Leftovers status
            Group {
                if isScanningLeftovers {
                    ProgressView().controlSize(.mini).tint(Theme.systemJunkAccent)
                } else if app.leftoverScanned {
                    if app.leftoverSize > 0 {
                        Text("+\(app.leftoverSize.compactBytes)")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.systemJunkAccent)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.statusSafe.opacity(0.7))
                    }
                } else {
                    Button {
                        onScanLeftovers()
                    } label: {
                        Text("Leftovers")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 70, alignment: .trailing)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }

    private func sizeColor(_ bytes: Int64) -> Color {
        if bytes > 1_000_000_000 { return Theme.appUninstallerAccent }
        if bytes > 500_000_000 { return Theme.systemJunkAccent }
        if bytes > 100_000_000 { return Theme.statusReview }
        return Theme.smartScanAccent
    }
}
