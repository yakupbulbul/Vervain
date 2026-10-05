import SwiftUI

struct LoginItemsView: View {
    @Environment(LoginItemsViewModel.self) private var vm
    @Environment(CleanupCoordinator.self) private var coord

    var body: some View {
        VStack(spacing: 0) {
            FeatureToolbar(title: "Login Items", subtitle: "Background jobs that start with your Mac") {
                if vm.state == .scanning {
                    ProgressView().controlSize(.small).tint(Theme.loginItemsAccent)
                } else {
                    Button(vm.state == .results ? "Re-Scan" : "Scan") { vm.scan() }
                        .buttonStyle(.borderedProminent).tint(Theme.loginItemsAccent)
                }
            }
            Divider().background(Theme.divider)
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.background)
        .foregroundStyle(Theme.textPrimary)
        .task { if vm.state == .idle { vm.scan() } }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.state {
        case .idle, .scanning:
            ProgressView().controlSize(.large).tint(Theme.loginItemsAccent)
        case .results:
            if vm.items.isEmpty {
                ContentUnavailableView("No Startup Items",
                                       systemImage: "checkmark.circle.fill",
                                       description: Text("No third-party launch agents or daemons were found."))
            } else {
                VStack(spacing: 0) {
                    List {
                        ForEach(vm.grouped(), id: \.scope) { group in
                            Section(group.scope.displayName) {
                                ForEach(group.items) { item in
                                    row(item)
                                        .listRowBackground(Theme.surfaceOverlay)
                                }
                            }
                        }
                    }
                    .listStyle(.inset)
                    .scrollContentBackground(.hidden)
                    Divider().background(Theme.divider)
                    bottomBar
                }
            }
        }
    }

    private func row(_ item: LoginItem) -> some View {
        HStack(spacing: 12) {
            if item.isRemovable {
                Button { vm.toggle(item) } label: {
                    Image(systemName: vm.selectedIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(vm.selectedIDs.contains(item.id) ? Theme.loginItemsAccent : Theme.textMuted)
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "lock.fill").foregroundStyle(Theme.textFaint).frame(width: 18)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.label).font(.system(size: 13, weight: .medium))
                Text(item.program ?? item.plistURL.path)
                    .font(.caption).foregroundStyle(Theme.textMuted)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            if item.isDisabled {
                Text("Disabled").font(.caption2).foregroundStyle(Theme.textMuted)
            } else if item.runsAtLoad {
                Text("Runs at login").font(.caption2).foregroundStyle(Theme.loginItemsAccent)
            }
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.plistURL])
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help("Reveal in Finder")
        }
        .padding(.vertical, 2)
    }

    private var bottomBar: some View {
        HStack {
            Text("System-wide items need administrator rights and can only be revealed in Finder.")
                .font(.caption).foregroundStyle(Theme.textSecondary)
            Spacer()
            Button("Review & Remove \(vm.selectedIDs.count)") {
                coord.startReview(vm.buildCleanupCategories(), title: String(localized: "Review Launch Agents")) {
                    vm.scan()
                }
            }
            .buttonStyle(.borderedProminent).tint(Theme.loginItemsAccent)
            .disabled(vm.selectedIDs.isEmpty)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(Theme.background)
    }
}
