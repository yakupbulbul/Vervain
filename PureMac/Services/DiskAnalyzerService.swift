import Foundation

actor DiskAnalyzerService {

    func analyze(root: URL, maxDepth: Int = 4) async throws -> DiskNode {
        // Use detached task to avoid blocking cooperative thread pool during
        // potentially large recursive file system enumeration.
        return try await Task.detached(priority: .userInitiated) {
            try buildTree(url: root, depth: 0, maxDepth: maxDepth)
        }.value
    }

    func getDiskUsageFraction() -> Double {
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        guard let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity,
              let avail = values.volumeAvailableCapacityForImportantUsage,
              total > 0
        else { return 0 }
        return 1.0 - (Double(avail) / Double(total))
    }
}

// nonisolated free function so Task.detached can call without hopping
private func buildTree(url: URL, depth: Int, maxDepth: Int) throws -> DiskNode {
    try Task.checkCancellation()
    let fm = FileManager.default
    let keys: Set<URLResourceKey> = [
        .isDirectoryKey, .fileSizeKey,
        .totalFileAllocatedSizeKey,
        .isSymbolicLinkKey
    ]

    let rv = (try? url.resourceValues(forKeys: keys)) ?? URLResourceValues()

    // Skip symlinks to avoid cycles
    if rv.isSymbolicLink == true {
        return DiskNode(url: url, name: url.lastPathComponent, size: 0, children: [], isDirectory: false)
    }

    if rv.isDirectory == true {
        var children: [DiskNode] = []
        if depth < maxDepth {
            let contents = (try? fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles]
            )) ?? []
            for child in contents {
                if let node = try? buildTree(url: child, depth: depth + 1, maxDepth: maxDepth) {
                    children.append(node)
                }
            }
        }
        // Sort children largest-first for display
        children.sort { $0.size > $1.size }
        let totalSize = children.reduce(Int64(0)) { $0 + $1.size }
        return DiskNode(url: url, name: url.lastPathComponent, size: totalSize, children: children, isDirectory: true)
    } else {
        let size = Int64(rv.totalFileAllocatedSize ?? rv.fileSize ?? 0)
        return DiskNode(url: url, name: url.lastPathComponent, size: size, children: [], isDirectory: false)
    }
}
