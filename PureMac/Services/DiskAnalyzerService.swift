import Foundation

/// Recursively measures disk usage. Cancellable via `Task.cancel`, reports
/// inaccessible folders via `ScanMetadata` instead of throwing.
actor DiskAnalyzerService {

    struct AnalysisResult: Sendable {
        let root: DiskNode
        let metadata: ScanMetadata
        let scannedFolders: Int
        let scannedFiles: Int
        let skippedSymlinks: Int
        let largestFiles: [DiskNode]
        let largestFolders: [DiskNode]
    }

    func analyze(root: URL, maxDepth: Int = 4) async throws -> AnalysisResult {
        let started = Date()

        // Run on a detached task so a long traversal doesn't pin the
        // cooperative pool. Counters are wrapped in a Sendable box so the
        // detached closure can mutate them without crossing actor isolation.
        return try await Task.detached(priority: .userInitiated) {
            let counters = AnalysisCounters()
            let rootNode = try buildTree(
                url: root, depth: 0, maxDepth: maxDepth, counters: counters
            )

            // Collect largest files / folders by walking the result tree.
            var allFiles: [DiskNode] = []
            var allFolders: [DiskNode] = []
            collect(node: rootNode, into: &allFiles, folders: &allFolders)
            let largestFiles  = Array(allFiles.sorted { $0.size > $1.size }.prefix(20))
            let largestFolders = Array(allFolders.sorted { $0.size > $1.size }.prefix(20))

            var meta = ScanMetadata()
            meta.inaccessibleCount = counters.inaccessibleCount
            meta.skippedCount = counters.skippedSymlinks
            meta.scannedCount = counters.scannedFiles + counters.scannedFolders
            meta.errors = counters.errors
            meta.duration = Date().timeIntervalSince(started)

            return AnalysisResult(
                root: rootNode,
                metadata: meta,
                scannedFolders: counters.scannedFolders,
                scannedFiles: counters.scannedFiles,
                skippedSymlinks: counters.skippedSymlinks,
                largestFiles: largestFiles,
                largestFolders: largestFolders
            )
        }.value
    }

    func getDiskUsageFraction() -> Double {
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ]
        guard let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity,
              let avail = values.volumeAvailableCapacityForImportantUsage,
              total > 0
        else { return 0 }
        return 1.0 - (Double(avail) / Double(total))
    }
}

// MARK: - Tree builder (non-isolated free function)

/// Reference-typed counter bag the recursive traversal mutates as it walks.
/// Wrapped in @unchecked Sendable because it's only ever owned by the single
/// Task.detached invocation that creates it.
private final class AnalysisCounters: @unchecked Sendable {
    var scannedFolders = 0
    var scannedFiles = 0
    var skippedSymlinks = 0
    var inaccessibleCount = 0
    var errors: [ScanError] = []
}

private func buildTree(
    url: URL,
    depth: Int,
    maxDepth: Int,
    counters: AnalysisCounters
) throws -> DiskNode {
    try Task.checkCancellation()

    let fm = FileManager.default
    let keys: Set<URLResourceKey> = [
        .isDirectoryKey, .fileSizeKey,
        .totalFileAllocatedSizeKey, .isSymbolicLinkKey
    ]
    let rv = (try? url.resourceValues(forKeys: keys)) ?? URLResourceValues()

    if rv.isSymbolicLink == true {
        counters.skippedSymlinks += 1
        return DiskNode(
            url: url, name: url.lastPathComponent,
            size: 0, children: [], isDirectory: false
        )
    }

    if rv.isDirectory == true {
        counters.scannedFolders += 1
        var children: [DiskNode] = []
        if depth < maxDepth {
            do {
                let contents = try fm.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: Array(keys),
                    options: [.skipsHiddenFiles]
                )
                for child in contents {
                    do {
                        let node = try buildTree(
                            url: child, depth: depth + 1,
                            maxDepth: maxDepth, counters: counters
                        )
                        children.append(node)
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        // Per-child failures are recorded but don't abort.
                        counters.errors.append(ScanError(
                            path: child.path,
                            reason: .other(message: error.localizedDescription)
                        ))
                    }
                }
            } catch {
                // Whole directory inaccessible (permission denied etc.)
                counters.inaccessibleCount += 1
                counters.errors.append(ScanError(
                    path: url.path,
                    reason: .permissionDenied
                ))
            }
        }
        children.sort { $0.size > $1.size }
        let totalSize = children.reduce(Int64(0)) { $0 + $1.size }
        return DiskNode(
            url: url, name: url.lastPathComponent,
            size: totalSize, children: children, isDirectory: true
        )
    } else {
        counters.scannedFiles += 1
        let size = Int64(rv.totalFileAllocatedSize ?? rv.fileSize ?? 0)
        return DiskNode(
            url: url, name: url.lastPathComponent,
            size: size, children: [], isDirectory: false
        )
    }
}

private func collect(
    node: DiskNode,
    into files: inout [DiskNode],
    folders: inout [DiskNode]
) {
    if node.isDirectory {
        folders.append(node)
        for child in node.children { collect(node: child, into: &files, folders: &folders) }
    } else if node.size > 0 {
        files.append(node)
    }
}
