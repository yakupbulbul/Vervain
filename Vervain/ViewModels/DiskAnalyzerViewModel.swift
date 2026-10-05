import SwiftUI

@Observable
@MainActor
final class DiskAnalyzerViewModel {

    enum State {
        case idle, analyzing, results, error(String)

        var isAnalyzing: Bool {
            if case .analyzing = self { return true }
            return false
        }
    }

    var state: State = .idle
    var rootNode: DiskNode?
    var selectedNode: DiskNode?
    var breadcrumbs: [DiskNode] = []
    var metadata = ScanMetadata()
    var scannedFolders: Int = 0
    var scannedFiles: Int = 0
    var skippedSymlinks: Int = 0
    var largestFiles: [DiskNode] = []
    var selectedFileIDs: Set<UUID> = []

    // Whole-disk progress & capacity
    var scanningPath: String = ""
    var diskTotalBytes: Int64 = 0
    var diskFreeBytes: Int64  = 0
    var diskUsedBytes: Int64  { diskTotalBytes - diskFreeBytes }

    var isAnalyzing: Bool { state.isAnalyzing }

    /// Top N children of the selected node, sorted by size, for chart display.
    var chartItems: [DiskNode] {
        let node = selectedNode ?? rootNode
        guard let node else { return [] }
        return Array(node.children.prefix(8))
    }

    var selectedLargeFiles: [DiskNode] {
        largestFiles.filter { selectedFileIDs.contains($0.id) }
    }
    var selectedLargeFilesSize: Int64 {
        selectedLargeFiles.reduce(0) { $0 + $1.size }
    }

    private let service = DiskAnalyzerService()
    private var analyzeTask: Task<Void, Never>?

    // MARK: - Analyze

    func analyze() {
        analyzeTask?.cancel()
        scanningPath = ""
        analyzeTask = Task {
            state = .analyzing
            do {
                let result = try await service.analyzeWholeDisk(
                    maxDepth: 5,
                    progress: { @MainActor [weak self] label in
                        self?.scanningPath = "Scanning \(label)…"
                    }
                )
                rootNode        = result.root
                selectedNode    = result.root
                breadcrumbs     = [result.root]
                metadata        = result.metadata
                scannedFolders  = result.scannedFolders
                scannedFiles    = result.scannedFiles
                skippedSymlinks = result.skippedSymlinks
                largestFiles    = result.largestFiles
                diskTotalBytes  = result.totalDiskBytes
                diskFreeBytes   = result.freeDiskBytes
                selectedFileIDs.removeAll()
                state = .results
            } catch is CancellationError {
                state = .idle
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    /// Analyzes a single folder instead of the whole disk.
    func analyzeFolder(_ url: URL) {
        analyzeTask?.cancel()
        scanningPath = String(localized: "Scanning \(url.lastPathComponent)…")
        analyzeTask = Task {
            state = .analyzing
            do {
                let result = try await service.analyze(root: url, maxDepth: 5)
                rootNode        = result.root
                selectedNode    = result.root
                breadcrumbs     = [result.root]
                metadata        = result.metadata
                scannedFolders  = result.scannedFolders
                scannedFiles    = result.scannedFiles
                skippedSymlinks = result.skippedSymlinks
                largestFiles    = result.largestFiles
                diskTotalBytes  = 0     // hides the whole-disk capacity bar
                diskFreeBytes   = 0
                selectedFileIDs.removeAll()
                state = .results
            } catch is CancellationError {
                state = rootNode == nil ? .idle : .results
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    /// Drops nodes whose files no longer exist (after a cleanup) instead of
    /// re-scanning the whole disk.
    func pruneMissing() {
        guard let root = rootNode else { return }
        Self.prune(root)
        largestFiles.removeAll { !FileManager.default.fileExists(atPath: $0.url.path) }
        selectedFileIDs = selectedFileIDs.intersection(Set(largestFiles.map(\.id)))
        // Re-assigning makes observers re-read the (reference-type) tree.
        rootNode = root
        selectedNode = selectedNode
    }

    /// Removes missing children recursively and shrinks sizes to match.
    /// Returns the number of bytes removed below `node`.
    @discardableResult
    nonisolated static func prune(_ node: DiskNode, fileManager: FileManager = .default) -> Int64 {
        guard node.isDirectory else { return 0 }
        var removed: Int64 = 0
        var kept: [DiskNode] = []
        for child in node.children {
            if fileManager.fileExists(atPath: child.url.path) {
                removed += prune(child, fileManager: fileManager)
                kept.append(child)
            } else {
                removed += child.size
            }
        }
        node.children = kept
        node.size -= removed
        return removed
    }

    /// A one-item review category for any file or folder in the tree.
    func reviewCategories(for node: DiskNode) -> [CleanupCategory] {
        let modified = Self.modificationDate(of: node.url)
        let item = CleanupItem(
            url: node.url,
            size: node.size,
            category: node.isDirectory ? "Folders" : "Files",
            reason: .custom(node.isDirectory
                            ? String(localized: "Folder chosen in Disk Analyzer")
                            : String(localized: "File chosen in Disk Analyzer")),
            riskLevel: .review,
            confidenceLevel: .medium,
            lastModifiedDate: modified,
            sourceModule: .diskAnalyzer
        )
        return [CleanupCategory(
            kind: .largeFiles,
            title: node.name,
            subtitle: String(localized: "Chosen in Disk Analyzer — review carefully before removing"),
            icon: node.isDirectory ? "folder.fill" : "doc.fill",
            sourceModule: .diskAnalyzer,
            items: [item]
        )]
    }

    nonisolated static func modificationDate(of url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    func cancelAnalyze() {
        analyzeTask?.cancel()
        state = rootNode == nil ? .idle : .results
    }

    // MARK: - Navigation

    func drillDown(into node: DiskNode) {
        guard node.isDirectory else { return }
        selectedNode = node
        if !breadcrumbs.contains(where: { $0.id == node.id }) {
            breadcrumbs.append(node)
        } else if let idx = breadcrumbs.firstIndex(where: { $0.id == node.id }) {
            breadcrumbs = Array(breadcrumbs.prefix(idx + 1))
        }
    }

    func navigateToBreadcrumb(_ node: DiskNode) {
        selectedNode = node
        if let idx = breadcrumbs.firstIndex(where: { $0.id == node.id }) {
            breadcrumbs = Array(breadcrumbs.prefix(idx + 1))
        }
    }

    // MARK: - Large-file selection

    func toggleLargeFile(_ id: UUID) {
        if selectedFileIDs.contains(id) { selectedFileIDs.remove(id) }
        else { selectedFileIDs.insert(id) }
    }

    /// Build a CleanupCategory of currently-selected large files so the user
    /// can push the selection into the universal review/confirmation flow.
    func buildLargeFileCleanupCategory() -> [CleanupCategory] {
        let items = selectedLargeFiles.map { node -> CleanupItem in
            let modified = Self.modificationDate(of: node.url)
            let ageDays = max(0, Int(Date().timeIntervalSince(modified ?? Date()) / 86_400))
            return CleanupItem(
                url: node.url,
                size: node.size,
                category: "Large Files",
                reason: .largeOldFile(ageDays: ageDays),
                riskLevel: .review,
                confidenceLevel: .medium,
                lastModifiedDate: modified,
                sourceModule: .diskAnalyzer
            )
        }
        guard !items.isEmpty else { return [] }
        return [CleanupCategory(
            kind: .largeFiles,
            title: "Large Files",
            subtitle: "User-owned files — review carefully before removing",
            icon: "doc.zipper",
            sourceModule: .diskAnalyzer,
            items: items
        )]
    }
}
