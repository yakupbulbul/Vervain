import SwiftUI

/// Generic scan-then-review view model shared by the newer modules
/// (Large & Old Files, Duplicates, Privacy). Each module supplies only its
/// scanner closure; state handling and selection live here.
@Observable
@MainActor
final class ModuleScanViewModel {

    typealias ScanOutput = (categories: [CleanupCategory], metadata: ScanMetadata)

    enum State: Equatable {
        case idle
        case scanning
        case results
        case error(String)
    }

    var state: State = .idle
    var categories: [CleanupCategory] = []
    var metadata = ScanMetadata()

    var isScanning: Bool { state == .scanning }
    var totalSelectedSize: Int64 { categories.reduce(0) { $0 + $1.selectedSize } }
    var totalSelectedCount: Int { categories.reduce(0) { $0 + $1.selectedCount } }
    var totalFoundSize: Int64 { categories.reduce(0) { $0 + $1.totalSize } }

    private let scanner: @Sendable () async throws -> ScanOutput
    private var scanTask: Task<Void, Never>?

    init(scanner: @escaping @Sendable () async throws -> ScanOutput) {
        self.scanner = scanner
    }

    func scan() {
        scanTask?.cancel()
        scanTask = Task {
            state = .scanning
            do {
                let output = try await scanner()
                let excluded = ExclusionList.paths()
                categories = Self.applyExclusions(output.categories, excluded: excluded)
                metadata = output.metadata
                state = .results
            } catch is CancellationError {
                state = .idle
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    func toggleCategory(_ id: UUID) {
        guard let idx = categories.firstIndex(where: { $0.id == id }) else { return }
        if categories[idx].allSelected {
            categories[idx].deselectAll()
        } else {
            categories[idx].selectAll()
        }
    }

    func resetToDefaults() {
        for idx in categories.indices { categories[idx].resetToDefaults() }
    }

    /// Removes excluded items and any category left empty.
    nonisolated static func applyExclusions(
        _ categories: [CleanupCategory],
        excluded: [String]
    ) -> [CleanupCategory] {
        guard !excluded.isEmpty else { return categories }
        return categories.compactMap { cat in
            var copy = cat
            copy.items.removeAll { ExclusionList.isExcluded($0.url, excluded: excluded) }
            return copy.items.isEmpty ? nil : copy
        }
    }
}
