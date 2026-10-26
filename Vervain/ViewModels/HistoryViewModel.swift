import SwiftUI

@Observable
@MainActor
final class HistoryViewModel {
    var entries: [CleanupHistoryEntry] = []
    var message: String?

    var totalFreedBytes: Int64 { entries.reduce(0) { $0 + $1.freedBytes } }
    var totalItems: Int { entries.reduce(0) { $0 + $1.itemCount } }

    func load() async {
        entries = await CleanupHistoryStore.shared.load()
    }

    func restore(_ item: TrashedItem) async {
        await restore([item])
    }

    func restore(_ entry: CleanupHistoryEntry) async {
        await restore(entry.items)
    }

    private func restore(_ items: [TrashedItem]) async {
        let outcome = await Task.detached { TrashRestorer.restoreAll(items) }.value
        await CleanupHistoryStore.shared.removeItems(Set(outcome.restored))
        let restored = outcome.restored.count
        let failed = outcome.failed.count
        message = failed == 0
            ? String(localized: "Put back \(restored) items.")
            : String(localized: "Put back \(restored) items. \(failed) could not be restored — they may no longer be in the Trash.")
        await load()
    }

    func clearHistory() async {
        await CleanupHistoryStore.shared.clear()
        message = nil
        await load()
    }
}
