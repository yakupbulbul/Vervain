import Foundation

/// One finished cleanup, as shown in the History screen.
struct CleanupHistoryEntry: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let date: Date
    let title: String
    var items: [TrashedItem]

    var itemCount: Int { items.count }
    var freedBytes: Int64 { items.reduce(0) { $0 + $1.size } }
}

/// Persists the cleanup history as JSON in Application Support. Local only.
actor CleanupHistoryStore {

    static let shared = CleanupHistoryStore()
    static let maxEntries = 500

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.fileURL = support.appendingPathComponent("Vervain/history.json")
        }
    }

    func load() -> [CleanupHistoryEntry] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return ((try? decoder.decode([CleanupHistoryEntry].self, from: data)) ?? [])
            .sorted { $0.date > $1.date }
    }

    func append(_ entry: CleanupHistoryEntry) {
        var all = load()
        all.insert(entry, at: 0)
        save(Array(all.prefix(Self.maxEntries)))
    }

    /// Removes `ids` from their entries (after a Put Back); empty entries disappear.
    func removeItems(_ ids: Set<UUID>) {
        let updated = load().compactMap { entry -> CleanupHistoryEntry? in
            var copy = entry
            copy.items.removeAll { ids.contains($0.id) }
            return copy.items.isEmpty ? nil : copy
        }
        save(updated)
    }

    func clear() {
        save([])
    }

    private func save(_ entries: [CleanupHistoryEntry]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entries) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }
}
