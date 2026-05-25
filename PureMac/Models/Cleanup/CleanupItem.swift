import Foundation

/// A single file/folder candidate for cleanup, fully described.
/// Carries everything the review UI needs to make the user comfortable: name,
/// path, size, why it was selected, how risky it is, and how confident we are.
struct CleanupItem: Identifiable, Sendable, Hashable {
    let id: UUID
    let url: URL
    let name: String
    /// User-friendly path (e.g. "~/Library/Caches/com.apple.Safari").
    let displayPath: String
    let size: Int64
    let category: String
    let reason: CleanupReason
    let riskLevel: CleanupRiskLevel
    let confidenceLevel: CleanupConfidenceLevel
    let lastModifiedDate: Date?
    let sourceModule: CleanupSourceModule
    /// Whether selection policy would allow this item to be on by default.
    /// Pre-computed at scan time via `CleanupSelectionPolicy`.
    let canSelectByDefault: Bool
    /// Live selection state — toggled by the review UI.
    var isSelected: Bool

    /// Convenience initialiser that applies the selection policy automatically.
    init(
        id: UUID = UUID(),
        url: URL,
        name: String? = nil,
        displayPath: String? = nil,
        size: Int64,
        category: String,
        reason: CleanupReason,
        riskLevel: CleanupRiskLevel,
        confidenceLevel: CleanupConfidenceLevel,
        lastModifiedDate: Date? = nil,
        sourceModule: CleanupSourceModule
    ) {
        self.id = id
        self.url = url
        self.name = name ?? url.lastPathComponent
        self.displayPath = displayPath ?? CleanupItem.makeDisplayPath(url: url)
        self.size = size
        self.category = category
        self.reason = reason
        self.riskLevel = riskLevel
        self.confidenceLevel = confidenceLevel
        self.lastModifiedDate = lastModifiedDate
        self.sourceModule = sourceModule
        self.canSelectByDefault = CleanupSelectionPolicy.defaultSelection(
            risk: riskLevel,
            confidence: confidenceLevel,
            reason: reason
        )
        self.isSelected = self.canSelectByDefault
    }

    /// Replaces the home directory with `~` for a friendlier display.
    static func makeDisplayPath(url: URL) -> String {
        let path = url.path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}

// MARK: - Hashable (UUID-based)

extension CleanupItem {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: CleanupItem, rhs: CleanupItem) -> Bool { lhs.id == rhs.id }
}
