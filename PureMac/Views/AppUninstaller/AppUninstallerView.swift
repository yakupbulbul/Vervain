import SwiftUI

struct AppUninstallerView: View {
    @Environment(AppUninstallerViewModel.self) private var vm

    var body: some View {
        VStack(spacing: 0) {
            FeatureToolbar(title: "App Uninstaller", subtitle: "Remove apps and their leftovers") {
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
        case .results, .uninstalling, .done:
            HStack(spacing: 8) {
                if vm.state == .done {
                    Button("Scan Again") { vm.scan() }
                        .buttonStyle(.bordered)
                        .foregroundStyle(.white)
                        .controlSize(.small)
                } else {
                    Button("Re-Scan") { vm.scan() }
                        .buttonStyle(.bordered)
                        .foregroundStyle(.white)
                        .controlSize(.small)
                }
            }
        default:
            Button("Scan Apps") { vm.scan() }
                .buttonStyle(.borderedProminent)
                .tint(.red)
        }
    }

    // MARK: - Main content

    @ViewBuilder
    private var mainContent: some View {
        switch vm.state {
        case .idle:
            idleView
        case .scanning:
            loadingView
        case .results, .uninstalling, .done:
            if vm.apps.isEmpty {
                ContentUnavailableView(
                    "No Apps Found",
                    systemImage: "app.badge.minus",
                    description: Text("No applications found in /Applications.")
                )
                .foregroundStyle(.white)
            } else {
                appListView
            }
        }
    }

    // MARK: - Views

    private var idleView: some View {
        VStack(spacing: 28) {
            Image(systemName: "app.badge.minus")
                .font(.system(size: 76))
                .foregroundStyle(
                    LinearGradient(colors: [.red, .pink], startPoint: .top, endPoint: .bottom)
                )
                .symbolEffect(.pulse)

            VStack(spacing: 8) {
                Text("Remove Apps Completely")
                    .font(.title.bold())
                Text("Find all installed apps, their sizes,\nand hidden leftover files.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }

            Button("Scan Applications") { vm.scan() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.red)
        }
        .padding(40)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large).tint(.red)
            Text("Scanning /Applications…")
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var appListView: some View {
        VStack(spacing: 0) {
            // App rows
            List {
                ForEach(vm.apps) { app in
                    AppRow(
                        app: app,
                        isSelected: vm.selectedIDs.contains(app.id),
                        isScanningLeftovers: vm.scanningLeftoversID == app.id,
                        onToggle: { vm.toggleSelection(app.id) },
                        onScanLeftovers: { vm.scanLeftovers(for: app) }
                    )
                    .listRowBackground(
                        vm.selectedIDs.contains(app.id)
                            ? Color.red.opacity(0.12)
                            : Color.white.opacity(0.04)
                    )
                    .listRowSeparatorTint(Color.white.opacity(0.07))
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)

            // Bottom bar (shown when selection is non-empty)
            if !vm.selectedIDs.isEmpty {
                uninstallBar
            }
        }
    }

    private var uninstallBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(vm.selectedIDs.count) apps selected")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                Text(vm.totalSelectedSize.formattedBytes)
                    .font(.headline)
                    .foregroundStyle(.red)
            }
            Spacer()
            if vm.isUninstalling {
                ProgressView().controlSize(.small).tint(.red).padding(.trailing, 8)
            }
            Button(vm.isUninstalling ? "Uninstalling…" : "Uninstall \(vm.selectedIDs.count) Apps") {
                vm.uninstall()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(vm.isUninstalling)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
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
        HStack(spacing: 14) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .red : .white.opacity(0.3))
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)

            // Icon
            AppIconView(appURL: app.url)
                .frame(width: 32, height: 32)

            // Name + bundle ID
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text(app.bundleID)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1)
            }

            Spacer()

            // Bundle size
            SizeBadge(bytes: app.bundleSize, color: .blue)

            // Leftovers column
            Group {
                if isScanningLeftovers {
                    ProgressView().controlSize(.mini).tint(.orange)
                        .frame(width: 70)
                } else if app.leftoverScanned {
                    if app.leftoverSize > 0 {
                        SizeBadge(bytes: app.leftoverSize, color: .orange)
                            .frame(width: 70, alignment: .trailing)
                    } else {
                        Text("Clean")
                            .font(.caption)
                            .foregroundStyle(.green.opacity(0.8))
                            .frame(width: 70, alignment: .trailing)
                    }
                } else {
                    Button("Leftovers") { onScanLeftovers() }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(width: 70, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
    }
}
