import SwiftUI

/// State machine that owns the entire cleanup flow:
///   idle → reviewing → (confirming if risky) → executing → done → idle
///
/// Every module pushes its cleanup candidates here via `startReview`. The
/// view layer observes `state` and presents the appropriate sheet/screen.
/// This guarantees no deletion happens without an explicit user step.
@Observable
@MainActor
final class CleanupCoordinator {

    enum State: Equatable {
        case idle
        case reviewing
        case confirming
        case executing
        case done
    }

    /// "Always ask me to confirm" in Settings.
    static let alwaysConfirmKey = "alwaysConfirmCleanup"

    var state: State = .idle
    var categories: [CleanupCategory] = []
    var progress: CleanupProgress?
    var result: CleanupResult?
    var errorMessage: String?
    /// Outcome line shown on the done screen after "Undo".
    var undoSummary: String?
    var isUndoing = false

    /// Title shown in the review header — set by the calling module.
    var presentationTitle: String = String(localized: "Review Cleanup")

    /// True if the review sheet should be presented.
    var isReviewPresented: Bool {
        get {
            switch state {
            case .reviewing, .confirming, .executing, .done: return true
            default: return false
            }
        }
        set {
            if !newValue { cancel() }
        }
    }

    private let service = CleanupService()
    private var executeTask: Task<Void, Never>?
    private var onComplete: (() -> Void)?

    // MARK: - Derived

    var totalSelectedSize: Int64 {
        categories.reduce(0) { $0 + $1.selectedSize }
    }
    var totalSelectedCount: Int {
        categories.reduce(0) { $0 + $1.selectedCount }
    }
    var selectedItems: [CleanupItem] {
        categories.flatMap { $0.items.filter(\.isSelected) }
    }
    var riskyItems: [CleanupItem] {
        selectedItems.filter { $0.riskLevel == .risky }
    }
    var reviewItems: [CleanupItem] {
        selectedItems.filter { $0.riskLevel == .review }
    }
    var hasAnyRiskySelected: Bool { !riskyItems.isEmpty }
    var hasAnyReviewSelected: Bool { !reviewItems.isEmpty }

    // MARK: - Flow

    /// Module entry point: opens the universal review sheet with these
    /// categories pre-loaded.
    func startReview(_ categories: [CleanupCategory], title: String = String(localized: "Review Cleanup"), onComplete: (() -> Void)? = nil) {
        self.onComplete = onComplete
        self.categories = ModuleScanViewModel.applyExclusions(categories, excluded: ExclusionList.paths())
        self.presentationTitle = title
        self.progress = nil
        self.result = nil
        self.undoSummary = nil
        self.errorMessage = nil
        self.state = .reviewing
    }

    /// User pressed "Clean N items" on the review screen.
    /// Routes to a confirmation sheet if anything risky is selected.
    func confirm() {
        let alwaysConfirm = UserDefaults.standard.bool(forKey: Self.alwaysConfirmKey)
        if alwaysConfirm || hasAnyRiskySelected || hasAnyReviewSelected {
            state = .confirming
        } else {
            executeNow()
        }
    }

    /// User accepted the risk confirmation, or there was nothing risky.
    func executeNow() {
        executeTask?.cancel()
        executeTask = Task {
            state = .executing
            do {
                let snapshot = categories
                let res = try await service.execute(snapshot) { [weak self] p in
                    Task { @MainActor in
                        // Ticks hop actors and can arrive out of order; never go backwards.
                        if let current = self?.progress, current.currentIndex > p.currentIndex { return }
                        self?.progress = p
                    }
                }
                // Remove only what reached the Trash; failed items stay visible.
                let movedIDs = Set(res.trashed.map(\.id))
                for idx in categories.indices {
                    categories[idx].items.removeAll { movedIDs.contains($0.id) }
                }
                categories.removeAll { $0.items.isEmpty }
                self.result = res
                if res.wasCancelled && res.trashed.isEmpty {
                    self.state = .reviewing
                } else {
                    self.state = .done
                    recordHistory(res)
                }
            } catch is CancellationError {
                self.state = .reviewing
            } catch {
                self.errorMessage = error.localizedDescription
                self.state = .reviewing
            }
        }
    }

    private func recordHistory(_ result: CleanupResult) {
        guard !result.trashed.isEmpty else { return }
        let entry = CleanupHistoryEntry(
            id: UUID(), date: Date(), title: presentationTitle, items: result.trashed)
        Task { await CleanupHistoryStore.shared.append(entry) }
    }

    /// Puts everything from the last cleanup back where it was.
    func undoLastCleanup() {
        guard let items = result?.trashed, !items.isEmpty, !isUndoing else { return }
        isUndoing = true
        Task {
            let outcome = await Task.detached { TrashRestorer.restoreAll(items) }.value
            await CleanupHistoryStore.shared.removeItems(Set(outcome.restored))
            let restored = outcome.restored.count
            let failed = outcome.failed.count
            undoSummary = failed == 0
                ? String(localized: "Put back \(restored) items.")
                : String(localized: "Put back \(restored) items. \(failed) could not be restored — check the Trash.")
            if var res = result {
                let back = Set(outcome.restored)
                res.trashed.removeAll { back.contains($0.id) }
                result = res
            }
            isUndoing = false
        }
    }

    /// User stepped back from confirmation to the review screen.
    func backToReview() { state = .reviewing }

    /// User closed the cleanup sheet at any stage.
    func cancel() {
        onComplete = nil    // discarded — no cleanup happened on cancel path
        executeTask?.cancel()
        executeTask = nil
        state = .idle
        categories = []
        progress = nil
        result = nil
        undoSummary = nil
        isUndoing = false
    }

    /// User pressed Done on the result screen.
    func finish() {
        onComplete?()   // call before cancel() clears it
        onComplete = nil
        cancel()
    }

    // MARK: - Selection helpers (mirror SystemJunkViewModel for reuse)

    func toggleItem(categoryID: UUID, itemID: UUID) {
        guard let idx = categories.firstIndex(where: { $0.id == categoryID }) else { return }
        categories[idx].toggle(itemID: itemID)
    }

    func toggleCategory(_ categoryID: UUID) {
        guard let idx = categories.firstIndex(where: { $0.id == categoryID }) else { return }
        if categories[idx].allSelected {
            categories[idx].deselectAll()
        } else {
            categories[idx].selectAll()
        }
    }

    /// Sets the selection of exactly these items, leaving the rest untouched.
    func setSelected(_ selected: Bool, ids: Set<UUID>) {
        for c in categories.indices {
            for i in categories[c].items.indices where ids.contains(categories[c].items[i].id) {
                categories[c].items[i].isSelected = selected
            }
        }
    }

    /// Selects every item whose risk is `.safe` and nothing else.
    func selectOnlySafe() {
        for c in categories.indices {
            for i in categories[c].items.indices {
                categories[c].items[i].isSelected = categories[c].items[i].riskLevel == .safe
            }
        }
    }

    func clearSelection() {
        for c in categories.indices { categories[c].deselectAll() }
    }

    func resetToDefaults() {
        for idx in categories.indices { categories[idx].resetToDefaults() }
    }
}
