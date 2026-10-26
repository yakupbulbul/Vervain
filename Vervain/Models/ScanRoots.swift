import Foundation

/// The folders Large & Old Files and Duplicates look through: the personal
/// folders plus any the user added in Settings.
enum ScanRoots {
    static let defaultsKey = "extraScanRoots"

    static func extras(_ defaults: UserDefaults = .standard) -> [String] {
        defaults.stringArray(forKey: defaultsKey) ?? []
    }

    static func add(_ path: String, to defaults: UserDefaults = .standard) {
        let normalized = URL(fileURLWithPath: path).standardizedFileURL.path
        guard normalized != "/", !normalized.isEmpty else { return }
        var all = extras(defaults)
        guard !all.contains(normalized) else { return }
        all.append(normalized)
        defaults.set(all, forKey: defaultsKey)
    }

    static func remove(_ path: String, from defaults: UserDefaults = .standard) {
        defaults.set(extras(defaults).filter { $0 != path }, forKey: defaultsKey)
    }

    /// Personal folders first, then the user's extras, without overlap: a folder
    /// already inside another root is dropped so nothing is scanned twice.
    static func all(
        defaults: UserDefaults = .standard,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> [URL] {
        let candidates = personalFolderRoots(home: home)
            + extras(defaults).map { URL(fileURLWithPath: $0) }
        var result: [URL] = []
        for url in candidates.map({ $0.standardizedFileURL }) {
            let path = url.path
            if result.contains(where: { path == $0.path || path.hasPrefix($0.path + "/") }) { continue }
            result.removeAll { $0.path.hasPrefix(path + "/") }
            result.append(url)
        }
        return result
    }
}
