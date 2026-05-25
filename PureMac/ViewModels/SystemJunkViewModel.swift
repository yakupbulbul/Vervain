import SwiftUI

@Observable
@MainActor
final class SystemJunkViewModel {

    enum State {
        case idle
        case scanning
        case results
        case cleaning
        case done(CleanupResult)
        case error(String)
    }

    var state: State = .idle
    var categories: [CleanupCategory] = []
    var metadata = ScanMetadata()
    var progress: CleanupProgress?

    var isScanning: Bool {
        if case .scanning = state { return true }
        return false
    }
    var isCleaning: Bool {
        if case .cleaning = state { return true }
        return false
    }

    var totalSelectedSize: Int64 {
        categories.reduce(0) { $0 + $1.selectedSize }
    }

    var totalSelectedCount: Int {
        categories.reduce(0) { $0 + $1.selectedCount }
    }

    var hasAnyRiskySelected: Bool {
        categories.contains { cat in
            cat.items.contains { $0.isSelected && $0.riskLevel == .risky }
        }
    }

    private let scanner = JunkScanner()
    private let cleanupService = CleanupService()
    private var scanTask: Task<Void, Never>?
    private var cleanTask: Task<Void, Never>?

    // MARK: - Scanning

    func scan() {
        scanTask?.cancel()
        scanTask = Task {
            state = .scanning
            do {
                let (cats, meta) = try await scanner.scan()
                categories = cats
                metadata = meta
                state = .results
            } catch is CancellationError {
                state = .idle
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    // MARK: - Selection

    func toggleCategory(_ id: UUID) {
        guard let idx = categories.firstIndex(where: { $0.id == id }) else { return }
        if categories[idx].allSelected {
            categories[idx].deselectAll()
        } else {
            categories[idx].selectAll()
        }
    }

    func toggleItem(categoryID: UUID, itemID: UUID) {
        guard let idx = categories.firstIndex(where: { $0.id == categoryID }) else { return }
        categories[idx].toggle(itemID: itemID)
    }

    func selectAll() {
        for idx in categories.indices { categories[idx].selectAll() }
    }

    func resetToDefaults() {
        for idx in categories.indices { categories[idx].resetToDefaults() }
    }

    // MARK: - Cleanup

    func clean() {
        cleanTask?.cancel()
        cleanTask = Task {
            state = .cleaning
            progress = nil
            do {
                let toClean = categories
                let result = try await cleanupService.execute(toClean) { [weak self] p in
                    Task { @MainActor in
                        self?.progress = p
                    }
                }
                // Remove cleaned items from categories
                for idx in categories.indices {
                    categories[idx].items.removeAll { $0.isSelected }
                }
                categories.removeAll { $0.items.isEmpty }
                state = .done(result)
            } catch is CancellationError {
                state = .results
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    func dismissResult() {
        state = categories.isEmpty ? .idle : .results
        progress = nil
    }
}
