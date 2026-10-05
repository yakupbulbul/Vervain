import SwiftUI

struct HistoryView: View {
    @Environment(HistoryViewModel.self) private var vm

    var body: some View {
        VStack(spacing: 0) {
            FeatureToolbar(title: "History", subtitle: "Everything Vervain moved to the Trash") {
                if !vm.entries.isEmpty {
                    Button("Clear History") { Task { await vm.clearHistory() } }
                        .buttonStyle(.bordered).controlSize(.small).foregroundStyle(Theme.textPrimary)
                }
            }
            Divider().background(Theme.divider)
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.background)
        .foregroundStyle(Theme.textPrimary)
        .task { await vm.load() }
    }

    @ViewBuilder
    private var content: some View {
        if vm.entries.isEmpty {
            ContentUnavailableView("No Cleanups Yet",
                                   systemImage: "clock.arrow.circlepath",
                                   description: Text("Cleanups you run will appear here so you can put items back."))
        } else {
            VStack(spacing: 0) {
                header
                List {
                    ForEach(vm.entries) { entry in
                        DisclosureGroup {
                            ForEach(entry.items) { item in
                                itemRow(item)
                            }
                        } label: {
                            entryLabel(entry)
                        }
                        .listRowBackground(Theme.surfaceOverlay)
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.totalFreedBytes.formattedBytes)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.smartScanAccent)
                Text("\(vm.totalItems) items moved to the Trash")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if let message = vm.message {
                Text(message).font(.caption).foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
    }

    private func entryLabel(_ entry: CleanupHistoryEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title).font(.system(size: 13, weight: .medium))
                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundStyle(Theme.textMuted)
            }
            Spacer()
            Text("\(entry.itemCount) · \(entry.freedBytes.formattedBytes)")
                .font(.caption).foregroundStyle(Theme.textSecondary)
            Button("Put Back All") { Task { await vm.restore(entry) } }
                .buttonStyle(.bordered).controlSize(.small)
        }
    }

    private func itemRow(_ item: TrashedItem) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                Text(CleanupItem.makeDisplayPath(url: item.originalURL))
                    .font(.caption2).foregroundStyle(Theme.textMuted)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Text(item.size.formattedBytes).font(.caption).foregroundStyle(Theme.textSecondary)
            if let trash = item.trashURL {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([trash])
                } label: { Image(systemName: "magnifyingglass") }
                .buttonStyle(.borderless)
                .help("Reveal in Trash")
            }
            Button("Put Back") { Task { await vm.restore(item) } }
                .buttonStyle(.borderless)
        }
    }
}
