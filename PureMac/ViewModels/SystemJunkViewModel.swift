import SwiftUI

@Observable
@MainActor
final class SystemJunkViewModel {

    enum State: Equatable {
        case idle
        case scanning
        case results
        case error(String)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.scanning, .scanning), (.results, .results): return true
            case (.error(let l), .error(let r)): return l == r
            default: return false
            }
        }
    }

    var state: State = .idle
    var categories: [CleanupCategory] = []
    var metadata = ScanMetadata()

    var isScanning: Bool { state == .scanning }

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
    private var scanTask: Task<Void, Never>?

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
}
