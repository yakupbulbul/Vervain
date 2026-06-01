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
        let totalDiskBytes: Int64   // volume total capacity
        let freeDiskBytes: Int64    // volume available capacity
    }

    // Directories that must never be descended into during a whole-disk scan.
    // • Volumes  — would double-count external drives / APFS sub-volumes
    // • dev/cores/net/home — virtual or automount pseudo-filesystems
    // • vm       — /private/var/vm holds swap files (huge, not user-useful)
    // • Spotlight / fseventsd — metadata-only dirs with misleading sizes
    nonisolated static let skipNames: Set<String> = [
        "Volumes",
        ".Spotlight-V100", ".fseventsd", ".DocumentRevisions-V100",
        "dev", "cores", "net", "home",
        "vm",
    ]

    // MARK: - Legacy single-root scan (unchanged for tests / HealthScore)

    func analyze(root: URL, maxDepth: Int = 4) async throws -> AnalysisResult {
        let started = Date()
        return try await Task.detached(priority: .userInitiated) {
            let counters = AnalysisCounters()
            let rootNode = try buildTree(
                url: root, depth: 0, maxDepth: maxDepth,
                counters: counters, skipNames: []
            )
            var allFiles: [DiskNode] = []
            var allFolders: [DiskNode] = []
            collect(node: rootNode, into: &allFiles, folders: &allFolders)
            let largestFiles   = Array(allFiles.sorted   { $0.size > $1.size }.prefix(20))
            let largestFolders = Array(allFolders.sorted { $0.size > $1.size }.prefix(20))

            var meta = ScanMetadata()
            meta.inaccessibleCount = counters.inaccessibleCount
            meta.skippedCount      = counters.skippedSymlinks
            meta.scannedCount      = counters.scannedFiles + counters.scannedFolders
            meta.errors            = counters.errors
            meta.duration          = Date().timeIntervalSince(started)

            return AnalysisResult(
                root: rootNode, metadata: meta,
                scannedFolders: counters.scannedFolders,
                scannedFiles: counters.scannedFiles,
                skippedSymlinks: counters.skippedSymlinks,
                largestFiles: largestFiles, largestFolders: largestFolders,
                totalDiskBytes: 0, freeDiskBytes: 0
            )
        }.value
    }

    // MARK: - Whole-disk scan

    /// Scans all significant top-level directories concurrently and returns a
    /// virtual "Macintosh HD" root that represents the whole used storage.
    /// Progress callback fires with a human-readable label before each root starts.
    func analyzeWholeDisk(
        maxDepth: Int = 5,
        progress: (@Sendable (String) async -> Void)? = nil
    ) async throws -> AnalysisResult {
        let started = Date()

        // Disk capacity from the filesystem attributes of "/"
        let attrs = (try? FileManager.default.attributesOfFileSystem(forPath: "/")) ?? [:]
        let totalBytes = (attrs[.systemSize]     as? Int64) ?? 0
        let freeBytes  = (attrs[.systemFreeSize] as? Int64) ?? 0

        // Top-level directories to scan, in priority order
        let roots: [(path: String, label: String)] = [
            ("/Users",        "Users"),
            ("/Applications", "Applications"),
            ("/Library",      "Library"),
            ("/System",       "System"),
            ("/opt",          "Optional Packages"),
            ("/usr",          "Unix System"),
            ("/var",          "Variable Data"),
        ]

        // Filter to roots that actually exist on this Mac
        let existingRoots = roots.filter {
            FileManager.default.fileExists(atPath: $0.path)
        }

        // Fire progress for the first root before the group starts
        // (subsequent roots fire inside the group tasks)
        if let first = existingRoots.first {
            await progress?(first.label)
        }

        let combined = AnalysisCounters()
        var childNodes: [DiskNode] = []
        let skipNames = DiskAnalyzerService.skipNames

        // Scan each root in its own child task (concurrent)
        try await withThrowingTaskGroup(of: (DiskNode, AnalysisCounters).self) { group in
            for (index, root) in existingRoots.enumerated() {
                let url = URL(fileURLWithPath: root.path)
                let label = root.label
                let onProgress = progress
                group.addTask {
                    // Signal progress for roots after the first
                    if index > 0 { await onProgress?(label) }
                    let c = AnalysisCounters()
                    let node = try buildTree(
                        url: url, depth: 0, maxDepth: maxDepth,
                        counters: c, skipNames: skipNames
                    )
                    return (node, c)
                }
            }
            for try await (node, c) in group {
                childNodes.append(node)
                combined.merge(c)
            }
        }

        // Sort largest-first
        childNodes.sort { $0.size > $1.size }

        // Add "System & Other" to account for APFS snapshots, swap, firmware, etc.
        let usedBytes   = totalBytes - freeBytes
        let scannedSize = childNodes.reduce(Int64(0)) { $0 + $1.size }
        let otherSize   = max(0, usedBytes - scannedSize)
        if otherSize > 0 {
            childNodes.append(DiskNode(
                url: URL(fileURLWithPath: "/"),
                name: "System & Other",
                size: otherSize, children: [], isDirectory: true
            ))
        }

        // Virtual root representing the whole used disk
        let rootNode = DiskNode(
            url: URL(fileURLWithPath: "/"),
            name: "Macintosh HD",
            size: max(usedBytes, scannedSize),
            children: childNodes, isDirectory: true
        )

        // Collect largest files / folders from all children
        var allFiles: [DiskNode] = []
        var allFolders: [DiskNode] = []
        for child in childNodes { collect(node: child, into: &allFiles, folders: &allFolders) }
        let largestFiles   = Array(allFiles.sorted   { $0.size > $1.size }.prefix(20))
        let largestFolders = Array(allFolders.sorted { $0.size > $1.size }.prefix(20))

        var meta = ScanMetadata()
        meta.inaccessibleCount = combined.inaccessibleCount
        meta.skippedCount      = combined.skippedSymlinks
        meta.scannedCount      = combined.scannedFiles + combined.scannedFolders
        meta.errors            = combined.errors
        meta.duration          = Date().timeIntervalSince(started)

        return AnalysisResult(
            root: rootNode, metadata: meta,
            scannedFolders: combined.scannedFolders,
            scannedFiles: combined.scannedFiles,
            skippedSymlinks: combined.skippedSymlinks,
            largestFiles: largestFiles, largestFolders: largestFolders,
            totalDiskBytes: totalBytes, freeDiskBytes: freeBytes
        )
    }

    // MARK: - Disk usage fraction (used by SmartScan / HealthScore)

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

// MARK: - Counter bag

/// Reference-typed counter bag the recursive traversal mutates as it walks.
/// Marked @unchecked Sendable: only ever owned by the single Task that creates it.
private final class AnalysisCounters: @unchecked Sendable {
    var scannedFolders    = 0
    var scannedFiles      = 0
    var skippedSymlinks   = 0
    var inaccessibleCount = 0
    var errors: [ScanError] = []

    func merge(_ other: AnalysisCounters) {
        scannedFolders    += other.scannedFolders
        scannedFiles      += other.scannedFiles
        skippedSymlinks   += other.skippedSymlinks
        inaccessibleCount += other.inaccessibleCount
        errors            += other.errors
    }
}

// MARK: - Tree builder (non-isolated free function)

private func buildTree(
    url: URL,
    depth: Int,
    maxDepth: Int,
    counters: AnalysisCounters,
    skipNames: Set<String>
) throws -> DiskNode {
    try Task.checkCancellation()

    // Skip virtual/metadata/automount directories
    if !skipNames.isEmpty && skipNames.contains(url.lastPathComponent) {
        return DiskNode(url: url, name: url.lastPathComponent,
                        size: 0, children: [], isDirectory: true)
    }

    let fm = FileManager.default
    let keys: Set<URLResourceKey> = [
        .isDirectoryKey, .fileSizeKey,
        .totalFileAllocatedSizeKey, .isSymbolicLinkKey
    ]
    let rv = (try? url.resourceValues(forKeys: keys)) ?? URLResourceValues()

    if rv.isSymbolicLink == true {
        counters.skippedSymlinks += 1
        return DiskNode(url: url, name: url.lastPathComponent,
                        size: 0, children: [], isDirectory: false)
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
                            maxDepth: maxDepth,
                            counters: counters,
                            skipNames: skipNames
                        )
                        children.append(node)
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        counters.errors.append(ScanError(
                            path: child.path,
                            reason: .other(message: error.localizedDescription)
                        ))
                    }
                }
            } catch {
                counters.inaccessibleCount += 1
                counters.errors.append(ScanError(
                    path: url.path, reason: .permissionDenied
                ))
            }
        }
        children.sort { $0.size > $1.size }
        let totalSize = children.reduce(Int64(0)) { $0 + $1.size }
        return DiskNode(url: url, name: url.lastPathComponent,
                        size: totalSize, children: children, isDirectory: true)
    } else {
        counters.scannedFiles += 1
        let size = Int64(rv.totalFileAllocatedSize ?? rv.fileSize ?? 0)
        return DiskNode(url: url, name: url.lastPathComponent,
                        size: size, children: [], isDirectory: false)
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
