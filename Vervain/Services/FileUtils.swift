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

/// Walks `base` recursively and calls `handle` for every regular,
/// non-symlink file. Packages (e.g. `.app`, `.photoslibrary`) are not entered.
/// Folders that cannot be read are returned as `ScanError`s instead of
/// being silently dropped. Throws `CancellationError` if the task is cancelled.
func walkRegularFiles(
    at base: URL,
    keys: Set<URLResourceKey>,
    skipHidden: Bool = true,
    handle: (URL, URLResourceValues) throws -> Void
) throws -> [ScanError] {
    let fm = FileManager.default
    guard fm.fileExists(atPath: base.path) else { return [] }

    final class ErrorBox: @unchecked Sendable { var errors: [ScanError] = [] }
    let box = ErrorBox()

    var allKeys = keys
    allKeys.insert(.isRegularFileKey)
    allKeys.insert(.isSymbolicLinkKey)

    var options: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
    if skipHidden { options.insert(.skipsHiddenFiles) }

    guard let enumerator = fm.enumerator(
        at: base,
        includingPropertiesForKeys: Array(allKeys),
        options: options,
        errorHandler: { url, _ in
            box.errors.append(ScanError(path: url.path, reason: .permissionDenied))
            return true
        }
    ) else { return [] }

    while let next = enumerator.nextObject() {
        try Task.checkCancellation()
        guard let url = next as? URL,
              let rv = try? url.resourceValues(forKeys: allKeys) else { continue }
        guard rv.isSymbolicLink != true, rv.isRegularFile == true else { continue }
        try handle(url, rv)
    }
    return box.errors
}

/// The user folders that hold personal files. Shared by the Large & Old Files
/// and Duplicates scanners.
func personalFolderRoots(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [URL] {
    ["Downloads", "Documents", "Desktop", "Movies", "Music", "Pictures"]
        .map { home.appendingPathComponent($0) }
}
