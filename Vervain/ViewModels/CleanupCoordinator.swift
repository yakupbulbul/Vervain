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

    var state: State = .idle
    var categories: [CleanupCategory] = []
    var progress: CleanupProgress?
    var result: CleanupResult?
    var errorMessage: String?

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
        self.categories = categories
        self.presentationTitle = title
        self.progress = nil
        self.result = nil
        self.errorMessage = nil
        self.state = .reviewing
    }

    /// User pressed "Clean N items" on the review screen.
    /// Routes to a confirmation sheet if anything risky is selected.
    func confirm() {
        if hasAnyRiskySelected || hasAnyReviewSelected {
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
                    Task { @MainActor in self?.progress = p }
                }
                // Remove cleaned items from the in-flight categories
                for idx in categories.indices {
                    categories[idx].items.removeAll { $0.isSelected }
                }
                categories.removeAll { $0.items.isEmpty }
                self.result = res
                self.state = .done
            } catch is CancellationError {
                self.state = .reviewing
            } catch {
                self.errorMessage = error.localizedDescription
                self.state = .reviewing
            }
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

    func resetToDefaults() {
        for idx in categories.indices { categories[idx].resetToDefaults() }
    }
}
