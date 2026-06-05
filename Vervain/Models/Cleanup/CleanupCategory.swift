import SwiftUI

/// A grouping of cleanup items shown together in the review UI.
/// E.g. "User Caches", "Old Logs", or per-app "Spotify · Leftovers".
struct CleanupCategory: Identifiable, Sendable {
    let id: UUID
    let kind: CleanupCategoryKind
    let title: String
    let subtitle: String?
    /// SF Symbol name.
    let icon: String
    let sourceModule: CleanupSourceModule
    var items: [CleanupItem]

    init(
        id: UUID = UUID(),
        kind: CleanupCategoryKind,
        title: String,
        subtitle: String? = nil,
        icon: String,
        sourceModule: CleanupSourceModule,
        items: [CleanupItem]
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.sourceModule = sourceModule
        self.items = items
    }

    // MARK: - Computed

    var totalSize: Int64 {
        items.reduce(0) { $0 + $1.size }
    }

    var selectedSize: Int64 {
        items.filter(\.isSelected).reduce(0) { $0 + $1.size }
    }

    var selectedCount: Int { items.lazy.filter(\.isSelected).count }
    var itemCount: Int { items.count }

    /// Summary of risk levels present in the category.
    var riskSummary: [CleanupRiskLevel: Int] {
        Dictionary(grouping: items, by: \.riskLevel).mapValues(\.count)
    }

    /// Highest risk level among currently selected items. Defaults to `.safe` if none are selected.
    var maxSelectedRisk: CleanupRiskLevel {
        items.filter(\.isSelected).map(\.riskLevel).max() ?? .safe
    }

    /// True if every item in the category is currently selected.
    var allSelected: Bool {
        !items.isEmpty && items.allSatisfy(\.isSelected)
    }

    /// True if no item is selected.
    var noneSelected: Bool { items.allSatisfy { !$0.isSelected } }
}

// MARK: - Mutation helpers

extension CleanupCategory {
    /// Toggle a single item by id.
    mutating func toggle(itemID: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[idx].isSelected.toggle()
    }

    /// Select all items in the category.
    mutating func selectAll() {
        for idx in items.indices { items[idx].isSelected = true }
    }

    /// Deselect all items in the category.
    mutating func deselectAll() {
        for idx in items.indices { items[idx].isSelected = false }
    }

    /// Reset selection to the canonical default for each item.
    mutating func resetToDefaults() {
        for idx in items.indices {
            items[idx].isSelected = items[idx].canSelectByDefault
        }
    }
}
