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
        analyzeTask = Task {
            state = .analyzing
            let homeURL = FileManager.default.homeDirectoryForCurrentUser
            do {
                let result = try await service.analyze(root: homeURL, maxDepth: 4)
                rootNode = result.root
                selectedNode = result.root
                breadcrumbs = [result.root]
                metadata = result.metadata
                scannedFolders = result.scannedFolders
                scannedFiles = result.scannedFiles
                skippedSymlinks = result.skippedSymlinks
                largestFiles = result.largestFiles
                selectedFileIDs.removeAll()
                state = .results
            } catch is CancellationError {
                state = .idle
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    func cancelAnalyze() {
        analyzeTask?.cancel()
        state = .idle
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
    /// All items are tagged `.review` / `.medium` — they're user-owned and
    /// must be checked before removal.
    func buildLargeFileCleanupCategory() -> [CleanupCategory] {
        let items = selectedLargeFiles.map { node -> CleanupItem in
            let ageDays = max(0, Int(Date().timeIntervalSince(
                (try? node.url.resourceValues(forKeys: [.contentModificationDateKey])
                    .contentModificationDate) ?? Date()
            ) / 86_400))
            return CleanupItem(
                url: node.url,
                size: node.size,
                category: "Large Files",
                reason: .largeOldFile(ageDays: ageDays),
                riskLevel: .review,
                confidenceLevel: .medium,
                lastModifiedDate: nil,
                sourceModule: .diskAnalyzer
            )
        }
        guard !items.isEmpty else { return [] }
        return [CleanupCategory(
            title: "Large Files",
            subtitle: "User-owned files — review carefully before removing",
            icon: "doc.zipper",
            sourceModule: .diskAnalyzer,
            items: items
        )]
    }
}
