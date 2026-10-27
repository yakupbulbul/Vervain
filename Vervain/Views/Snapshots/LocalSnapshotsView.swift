import SwiftUI

struct LocalSnapshotsView: View {
    @State private var vm = LocalSnapshotsViewModel()
    @State private var copiedCommand: String?

    var body: some View {
        VStack(spacing: 0) {
            FeatureToolbar(title: "Local Snapshots", subtitle: "Time Machine copies kept on this Mac") {
                if vm.state == .scanning {
                    ProgressView().controlSize(.small).tint(Theme.snapshotsAccent)
                } else {
                    Button("Re-Scan") { vm.scan() }
                        .buttonStyle(.borderedProminent).tint(Theme.snapshotsAccent)
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
            ProgressView().controlSize(.large).tint(Theme.snapshotsAccent)
        case .results:
            VStack(spacing: 0) {
                summary
                Divider().background(Theme.divider)
                if vm.report.snapshots.isEmpty {
                    ContentUnavailableView(
                        vm.report.errorMessage == nil ? "No Local Snapshots" : "Snapshots Unavailable",
                        systemImage: vm.report.errorMessage == nil ? "checkmark.circle.fill" : "exclamationmark.triangle",
                        description: Text(vm.report.errorMessage ?? String(localized: "Time Machine has not kept any copies on this Mac."))
                    )
                } else {
                    snapshotList
                    Divider().background(Theme.divider)
                    footer
                }
            }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(vm.report.purgeableBytes.formattedBytes)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.snapshotsAccent)
                Text("macOS can free on its own")
                    .font(.callout).foregroundStyle(Theme.textSecondary)
            }
            Text("macOS removes local snapshots automatically when it needs room, so you rarely have to. Vervain never deletes them itself: removal is permanent and needs administrator rights.")
                .font(.caption).foregroundStyle(Theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24).padding(.vertical, 16)
    }

    private var snapshotList: some View {
        List(vm.report.snapshots) { snapshot in
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.2.circlepath")
                    .foregroundStyle(Theme.snapshotsAccent).frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 13, weight: .medium))
                    Text(snapshot.name).font(.caption).foregroundStyle(Theme.textMuted)
                }
                Spacer()
                copyButton(String(localized: "Copy Command"), command: snapshot.deleteCommand)
            }
            .listRowBackground(Theme.surfaceOverlay)
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
    }

    private var footer: some View {
        HStack {
            Text("Paste the command into Terminal to remove a snapshot.")
                .font(.caption).foregroundStyle(Theme.textMuted)
            Spacer()
            copyButton(String(localized: "Copy Command for All"), command: LocalSnapshot.deleteAllCommand)
        }
        .padding(.horizontal, 24).padding(.vertical, 12)
    }

    private func copyButton(_ title: String, command: String) -> some View {
        Button(copiedCommand == command ? String(localized: "Copied") : title) {
            vm.copy(command)
            copiedCommand = command
        }
        .buttonStyle(.bordered)
    }
}
