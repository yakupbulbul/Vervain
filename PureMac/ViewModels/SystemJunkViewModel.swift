import SwiftUI

@Observable
@MainActor
final class SystemJunkViewModel {

    enum State {
        case idle, scanning, results, cleaning, done(Int64)
    }

    var state: State = .idle
    var categories: [JunkCategory] = []
    var errorMessage: String?

    var isScanning: Bool {
        if case .scanning = state { return true }
        return false
    }
    var isCleaning: Bool {
        if case .cleaning = state { return true }
        return false
    }

    var totalSelected: Int64 {
        categories
            .filter(\.isSelected)
            .flatMap(\.files)
            .reduce(0) { $0 + $1.size }
    }

    private let scanner = JunkScanner()
    private var scanTask: Task<Void, Never>?

    func scan() {
        scanTask?.cancel()
        scanTask = Task {
            state = .scanning
            errorMessage = nil
            do {
                let result = try await scanner.scan()
                categories = result.filter { $0.totalSize > 0 }
                state = .results
            } catch is CancellationError {
                state = .idle
            } catch {
                errorMessage = error.localizedDescription
                state = .idle
            }
        }
    }

    func toggleCategory(_ type: JunkCategoryType) {
        guard let idx = categories.firstIndex(where: { $0.id == type }) else { return }
        categories[idx].isSelected.toggle()
    }

    func selectAll() {
        for idx in categories.indices { categories[idx].isSelected = true }
    }

    func deselectAll() {
        for idx in categories.indices { categories[idx].isSelected = false }
    }

    func clean() {
        Task {
            state = .cleaning
            let filesToDelete = categories
                .filter(\.isSelected)
                .flatMap(\.files)
            do {
                let freed = try await scanner.deleteFiles(filesToDelete)
                categories.removeAll()
                state = .done(freed)
            } catch {
                errorMessage = error.localizedDescription
                state = .results
            }
        }
    }
}
