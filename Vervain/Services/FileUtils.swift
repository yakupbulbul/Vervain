import Foundation

/// Calculates the total allocated disk size of a file or directory.
/// `nonisolated` so it can be called from any actor context without hopping.
func directorySize(at url: URL) -> Int64 {
    let fm = FileManager.default
    let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .isRegularFileKey, .isSymbolicLinkKey]

    // Single file
    if let rv = try? url.resourceValues(forKeys: keys),
       rv.isRegularFile == true {
        return Int64(rv.totalFileAllocatedSize ?? 0)
    }

    // Directory
    guard let enumerator = fm.enumerator(
        at: url,
        includingPropertiesForKeys: Array(keys),
        options: [.skipsPackageDescendants]
    ) else { return 0 }

    var total: Int64 = 0
    for case let fileURL as URL in enumerator {
        if let rv = try? fileURL.resourceValues(forKeys: keys),
           rv.isSymbolicLink != true,
           rv.isRegularFile == true {
            total += Int64(rv.totalFileAllocatedSize ?? 0)
        }
    }
    return total
}

/// Allocated size plus the most recent modification date found anywhere
/// inside `url` (or the item itself when it is a single file). Used to treat a
/// whole folder as one cleanup item instead of listing every file in it.
struct DirectoryStats: Sendable {
    var size: Int64 = 0
    var newestModification: Date = .distantPast
    var inaccessibleCount: Int = 0
}

func directoryStats(at url: URL) -> DirectoryStats {
    let fm = FileManager.default
    let keys: Set<URLResourceKey> = [
        .totalFileAllocatedSizeKey, .isRegularFileKey, .isSymbolicLinkKey,
        .contentModificationDateKey
    ]
    var stats = DirectoryStats()

    func absorb(_ rv: URLResourceValues) {
        stats.size += Int64(rv.totalFileAllocatedSize ?? 0)
        if let m = rv.contentModificationDate, m > stats.newestModification {
            stats.newestModification = m
        }
    }

    if let rv = try? url.resourceValues(forKeys: keys), rv.isRegularFile == true {
        absorb(rv)
        return stats
    }

    final class ErrorCounter: @unchecked Sendable { var count = 0 }
    let counter = ErrorCounter()
    guard let enumerator = fm.enumerator(
        at: url,
        includingPropertiesForKeys: Array(keys),
        options: [.skipsPackageDescendants],
        errorHandler: { _, _ in counter.count += 1; return true }
    ) else { return stats }

    for case let fileURL as URL in enumerator {
        if let rv = try? fileURL.resourceValues(forKeys: keys),
           rv.isSymbolicLink != true,
           rv.isRegularFile == true {
            absorb(rv)
        }
    }
    stats.inaccessibleCount = counter.count
    return stats
}
