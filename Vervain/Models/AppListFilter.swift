import Foundation

/// Search, filter and sort for the App Uninstaller list. Pure value type.
struct AppListFilter: Equatable, Sendable {

    enum Sort: String, CaseIterable, Identifiable, Sendable {
        case size, name, lastUsed, installed

        var id: String { rawValue }

        var label: String {
            switch self {
            case .size:      return String(localized: "Size")
            case .name:      return String(localized: "Name")
            case .lastUsed:  return String(localized: "Last opened")
            case .installed: return String(localized: "Installed")
            }
        }
    }

    var query: String = ""
    var sort: Sort = .size
    /// Flips the natural order: largest first, A–Z, least recently opened first,
    /// newest install first.
    var reversed = false
    var unusedOnly = false
    var unusedMonths = 6
    var leftoversOnly = false

    func apply(to apps: [AppInfo], now: Date = Date()) -> [AppInfo] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        var result = apps.filter { app in
            if unusedOnly && !app.isUnused(forMonths: unusedMonths, now: now) { return false }
            if leftoversOnly && !app.hasLeftovers { return false }
            if needle.isEmpty { return true }
            return app.name.localizedCaseInsensitiveContains(needle)
                || app.bundleID.localizedCaseInsensitiveContains(needle)
        }
        switch sort {
        case .size:
            result.sort { $0.bundleSize > $1.bundleSize }
        case .name:
            result.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .lastUsed:
            result.sort { ($0.lastUsedDate ?? .distantPast) < ($1.lastUsedDate ?? .distantPast) }
        case .installed:
            result.sort { ($0.lastModifiedDate ?? .distantPast) > ($1.lastModifiedDate ?? .distantPast) }
        }
        return reversed ? result.reversed() : result
    }
}
