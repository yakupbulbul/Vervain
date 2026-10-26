import SwiftUI

/// Result screen after a cleanup batch. Always shows what was freed,
/// what failed, and how to reach the Trash.
struct CleanupDoneView: View {
    @Environment(CleanupCoordinator.self) private var coord

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    headerIcon
                    summaryBlock
                    if coord.result?.wasCancelled == true {
                        Text("Cleanup was stopped. Items already moved to the Trash are listed below.")
                            .font(.callout).foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    if let summary = coord.undoSummary {
                        Text(summary).font(.callout).foregroundStyle(Theme.statusSafe)
                    }
                    breakdownBlock
                    if let failures = coord.result?.failures, !failures.isEmpty {
                        failuresBlock(failures)
                    }
                }
                .padding(24)
            }
            Divider().background(Theme.divider)
            footer
        }
    }

    private var headerIcon: some View {
        let allOk = coord.result?.allSucceeded ?? true
        return VStack(spacing: 12) {
            Image(systemName: allOk ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(allOk ? Theme.statusSafe : Theme.statusReview)
                .symbolEffect(.bounce, value: true)
            Text(allOk ? "Cleanup Complete" : "Completed with Issues")
                .font(.title2.bold())
        }
    }

    private var summaryBlock: some View {
        VStack(spacing: 4) {
            Text(coord.result?.freedBytes.formattedBytes ?? "0 bytes")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.systemJunkAccent)
            Text("Freed by moving \(coord.result?.successCount ?? 0) items to Trash")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            if let res = coord.result, res.duration > 0 {
                Text(String(format: "in %.1fs", res.duration))
                    .font(.caption).foregroundStyle(Theme.textMuted)
            }
        }
    }

    /// Freed space per category, largest first.
    @ViewBuilder
    private var breakdownBlock: some View {
        let trashed = coord.result?.trashed ?? []
        let grouped = Dictionary(grouping: trashed, by: \.category)
            .map { (name: $0.key, count: $0.value.count, bytes: $0.value.reduce(Int64(0)) { $0 + $1.size }) }
            .sorted { $0.bytes > $1.bytes }
        if grouped.count > 1 {
            VStack(spacing: 4) {
                ForEach(grouped, id: \.name) { row in
                    HStack {
                        Text(row.name).font(.system(size: 12, weight: .medium))
                        Text("\(row.count)").font(.caption).foregroundStyle(Theme.textMuted)
                        Spacer()
                        Text(row.bytes.formattedBytes).font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .padding(10)
            .background(Theme.surfaceOverlay, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func failuresBlock(_ failures: [CleanupFailure]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.fdaBannerAccent)
                Text("\(failures.count) items could not be removed")
                    .font(.subheadline.bold())
            }
            VStack(spacing: 4) {
                ForEach(failures) { f in
                    HStack(spacing: 8) {
                        Text(f.item.name)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                        Text(f.reason.displayText)
                            .font(.caption).foregroundStyle(Theme.fdaBannerAccent.opacity(0.8))
                    }
                    .padding(.vertical, 3)
                }
            }
            .padding(10)
            .background(Theme.fdaBannerAccent.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            HStack(spacing: 8) {
                Button("Copy List") { copyFailures(failures) }
                    .buttonStyle(.bordered).controlSize(.small)
                if failures.contains(where: { $0.reason == .permissionDenied }) {
                    Button("Open Full Disk Access Settings") { FullDiskAccessProbe.openSystemSettings() }
                        .buttonStyle(.bordered).controlSize(.small)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            if !(coord.result?.trashed.isEmpty ?? true) {
                Button("Undo") { coord.undoLastCleanup() }
                    .buttonStyle(.bordered).foregroundStyle(Theme.textPrimary)
                    .disabled(coord.isUndoing)
                    .help("Put everything from this cleanup back where it was")
            }
            Button("Open Trash") { openTrash() }
                .buttonStyle(.bordered).foregroundStyle(Theme.textPrimary)
            Button("Done") { coord.finish() }
                .buttonStyle(.borderedProminent).tint(Theme.systemJunkAccent)
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
    }

    private func copyFailures(_ failures: [CleanupFailure]) {
        let text = failures
            .map { "\($0.item.displayPath)\t\($0.reason.displayText)" }
            .joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func openTrash() {
        let trash = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".Trash")
        NSWorkspace.shared.open(trash)
    }
}
