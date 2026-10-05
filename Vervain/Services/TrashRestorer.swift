import Foundation

/// Puts items back where they came from. Uses `moveItem` only (nothing is
/// deleted); an existing file at the original path is never overwritten.
enum TrashRestorer {

    enum RestoreError: Error, Equatable {
        case notInTrash          // unknown Trash location, or the item was already emptied/moved
    }

    struct Outcome: Sendable {
        var restored: [UUID] = []
        var failed: [UUID] = []
    }

    /// Moves `item` back to its original location and returns the final URL.
    @discardableResult
    static func restore(_ item: TrashedItem) throws -> URL {
        let fm = FileManager.default
        guard let source = item.trashURL, fm.fileExists(atPath: source.path) else {
            throw RestoreError.notInTrash
        }
        let original = item.originalURL
        try fm.createDirectory(at: original.deletingLastPathComponent(), withIntermediateDirectories: true)
        let destination = uniqueDestination(for: original)
        try fm.moveItem(at: source, to: destination)
        return destination
    }

    static func restoreAll(_ items: [TrashedItem]) -> Outcome {
        var outcome = Outcome()
        for item in items {
            do {
                try restore(item)
                outcome.restored.append(item.id)
            } catch {
                outcome.failed.append(item.id)
            }
        }
        return outcome
    }

    /// `name.ext` → `name (restored).ext` → `name (restored 2).ext` …
    static func uniqueDestination(for url: URL) -> URL {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return url }
        let folder = url.deletingLastPathComponent()
        let ext = url.pathExtension
        let base = url.deletingPathExtension().lastPathComponent
        var counter = 1
        while true {
            let suffix = counter == 1 ? " (restored)" : " (restored \(counter))"
            let name = ext.isEmpty ? base + suffix : base + suffix + "." + ext
            let candidate = folder.appendingPathComponent(name)
            if !fm.fileExists(atPath: candidate.path) { return candidate }
            counter += 1
        }
    }
}
