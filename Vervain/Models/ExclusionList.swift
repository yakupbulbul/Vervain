import Foundation

/// User-defined paths that Vervain must never offer for cleanup or trash.
/// Stored in `UserDefaults`; checked when a review opens and again right
/// before an item is trashed.
enum ExclusionList {
    static let defaultsKey = "excludedPaths"

    static func paths(_ defaults: UserDefaults = .standard) -> [String] {
        defaults.stringArray(forKey: defaultsKey) ?? []
    }

    static func add(_ path: String, to defaults: UserDefaults = .standard) {
        let normalized = normalize(path)
        var all = paths(defaults)
        guard !normalized.isEmpty, !all.contains(normalized) else { return }
        all.append(normalized)
        defaults.set(all, forKey: defaultsKey)
    }

    static func remove(_ path: String, from defaults: UserDefaults = .standard) {
        defaults.set(paths(defaults).filter { $0 != path }, forKey: defaultsKey)
    }

    /// True if `url` is one of the excluded paths or lives inside one.
    static func isExcluded(_ url: URL, excluded: [String]) -> Bool {
        let path = url.standardizedFileURL.path
        return excluded.contains { ex in
            path == ex || path.hasPrefix(ex.hasSuffix("/") ? ex : ex + "/")
        }
    }

    static func isExcluded(_ url: URL, defaults: UserDefaults = .standard) -> Bool {
        isExcluded(url, excluded: paths(defaults))
    }

    private static func normalize(_ path: String) -> String {
        let std = URL(fileURLWithPath: path).standardizedFileURL.path
        return std == "/" ? "" : std
    }
}
