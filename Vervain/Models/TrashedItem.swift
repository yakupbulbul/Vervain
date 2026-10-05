import Foundation

/// A record of one item Vervain moved to the Trash: where it came from and
/// where it ended up. This is what makes "Put Back" possible.
struct TrashedItem: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let originalPath: String
    /// Location inside the Trash; nil if macOS did not report one.
    let trashPath: String?
    let size: Int64
    let category: String

    var originalURL: URL { URL(fileURLWithPath: originalPath) }
    var trashURL: URL? { trashPath.map { URL(fileURLWithPath: $0) } }

    init(id: UUID = UUID(), name: String, originalPath: String, trashPath: String?, size: Int64, category: String) {
        self.id = id
        self.name = name
        self.originalPath = originalPath
        self.trashPath = trashPath
        self.size = size
        self.category = category
    }

    init(item: CleanupItem, size: Int64, trashURL: URL?) {
        self.init(
            id: item.id,
            name: item.name,
            originalPath: item.url.path,
            trashPath: trashURL?.path,
            size: size,
            category: item.category
        )
    }
}
