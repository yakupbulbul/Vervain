import SwiftUI

@Observable
@MainActor
final class DiskAnalyzerViewModel {

    enum State {
        case idle, analyzing, results
    }

    var state: State = .idle
    var rootNode: DiskNode?
    var selectedNode: DiskNode?
    var breadcrumbs: [DiskNode] = []
    var errorMessage: String?

    var isAnalyzing: Bool {
        if case .analyzing = state { return true }
        return false
    }

    /// Top N children of the selected node, sorted by size, for chart display.
    var chartItems: [DiskNode] {
        let node = selectedNode ?? rootNode
        guard let node else { return [] }
        return Array(node.children.prefix(8))
    }

    private let service = DiskAnalyzerService()

    func analyze() {
        Task {
            state = .analyzing
            errorMessage = nil
            let homeURL = FileManager.default.homeDirectoryForCurrentUser
            do {
                let root = try await service.analyze(root: homeURL, maxDepth: 4)
                rootNode = root
                selectedNode = root
                breadcrumbs = [root]
                state = .results
            } catch is CancellationError {
                state = .idle
            } catch {
                errorMessage = error.localizedDescription
                state = .idle
            }
        }
    }

    func drillDown(into node: DiskNode) {
        guard node.isDirectory else { return }
        selectedNode = node
        // Append to breadcrumbs if not already there
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
}
