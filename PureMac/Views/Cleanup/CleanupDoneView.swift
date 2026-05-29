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
            Text("freed by moving \(coord.result?.successCount ?? 0) item\((coord.result?.successCount ?? 0) == 1 ? "" : "s") to Trash")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            if let res = coord.result, res.duration > 0 {
                Text(String(format: "in %.1fs", res.duration))
                    .font(.caption).foregroundStyle(Theme.textMuted)
            }
        }
    }

    private func failuresBlock(_ failures: [CleanupFailure]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.fdaBannerAccent)
                Text("\(failures.count) item\(failures.count == 1 ? "" : "s") could not be removed")
                    .font(.subheadline.bold())
            }
            VStack(spacing: 4) {
                ForEach(failures.prefix(8)) { f in
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
                if failures.count > 8 {
                    Text("and \(failures.count - 8) more…")
                        .font(.caption).foregroundStyle(Theme.textMuted)
                }
            }
            .padding(10)
            .background(Theme.fdaBannerAccent.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Open Trash") { openTrash() }
                .buttonStyle(.bordered).foregroundStyle(Theme.textPrimary)
            Button("Done") { coord.finish() }
                .buttonStyle(.borderedProminent).tint(Theme.systemJunkAccent)
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
    }

    private func openTrash() {
        let trash = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".Trash")
        NSWorkspace.shared.open(trash)
    }
}
