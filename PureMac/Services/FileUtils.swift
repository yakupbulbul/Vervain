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
