import SwiftUI

/// The Time Machine snapshot overview, shown inside the Maintenance screen.
struct LocalSnapshotsSection: View {
    @State private var vm = LocalSnapshotsViewModel()
    @State private var copiedCommand: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Local Snapshots", systemImage: "clock.arrow.2.circlepath")
                    .font(.headline)
                Spacer()
                if vm.state == .scanning {
                    ProgressView().controlSize(.small)
                } else {
                    Button("Re-Scan") { vm.scan() }.buttonStyle(.bordered)
                }
            }
            if vm.state == .results {
                HStack(alignment: .firstTextBaseline) {
                    Text(vm.report.purgeableBytes.formattedBytes)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.snapshotsAccent)
                    Text("macOS can free on its own")
                        .font(.callout).foregroundStyle(Theme.textSecondary)
                }
                Text("macOS removes local snapshots automatically when it needs room, so you rarely have to. Vervain never deletes them itself: removal is permanent and needs administrator rights.")
                    .font(.caption).foregroundStyle(Theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                snapshotContent
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12))
        .task { if vm.state == .idle { vm.scan() } }
    }

    @ViewBuilder
    private var snapshotContent: some View {
        if vm.report.snapshots.isEmpty {
            Label(
                vm.report.errorMessage ?? String(localized: "Time Machine has not kept any copies on this Mac."),
                systemImage: vm.report.errorMessage == nil ? "checkmark.circle.fill" : "exclamationmark.triangle"
            )
            .font(.callout).foregroundStyle(Theme.textSecondary)
        } else {
            ForEach(vm.report.snapshots) { snapshot in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snapshot.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 13, weight: .medium))
                        Text(snapshot.name).font(.caption).foregroundStyle(Theme.textMuted)
                    }
                    Spacer()
                    copyButton(String(localized: "Copy Command"), command: snapshot.deleteCommand)
                }
            }
            HStack {
                Text("Paste the command into Terminal to remove a snapshot.")
                    .font(.caption).foregroundStyle(Theme.textMuted)
                Spacer()
                copyButton(String(localized: "Copy Command for All"), command: LocalSnapshot.deleteAllCommand)
            }
        }
    }

    private func copyButton(_ title: String, command: String) -> some View {
        Button(copiedCommand == command ? String(localized: "Copied") : title) {
            vm.copy(command)
            copiedCommand = command
        }
        .buttonStyle(.bordered)
    }
}
