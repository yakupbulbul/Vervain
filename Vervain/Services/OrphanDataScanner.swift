import Foundation

/// Finds data that apps left in `~/Library` after they were uninstalled.
///
/// An entry counts as orphaned when its name looks like a bundle identifier
/// and no installed app owns that identifier. This is a heuristic, so
/// everything is `.review` / medium-or-low confidence and never selected by
/// default, and anything touched in the last 30 days is left alone (the app
/// may simply live somewhere Vervain does not look).
actor OrphanDataScanner {

    static let recentDays = 30
    static let maxItems = 300

    private static let libraryFolders: [(path: String, confidence: CleanupConfidenceLevel)] = [
        ("Library/Containers", .medium),
        ("Library/Group Containers", .medium),
        ("Library/Preferences", .medium),
        ("Library/Application Support", .low),
        ("Library/Caches", .low),
        ("Library/Saved Application State", .low),
        ("Library/HTTPStorages", .low),
        ("Library/WebKit", .low),
        ("Library/Application Scripts", .low),
        ("Library/Logs", .low),
    ]

    private static let knownTLDs: Set<String> = [
        "com", "org", "net", "io", "app", "co", "me", "dev", "ai", "tv", "us", "uk",
        "de", "fr", "es", "tr", "cn", "jp", "ru", "nl", "se", "it", "ch", "at", "ca",
    ]

    func scan(
        home: URL? = nil,
        installedBundleIDs: Set<String>? = nil,
        now: Date? = nil
    ) async throws -> (categories: [CleanupCategory], metadata: ScanMetadata) {
        let started = Date()
        let home = home ?? FileManager.default.homeDirectoryForCurrentUser
        let installed = (installedBundleIDs ?? Self.installedBundleIDs()).map { $0.lowercased() }
        let now = now ?? Date()
        var meta = ScanMetadata()
        var items: [CleanupItem] = []
        let fm = FileManager.default

        for (path, confidence) in Self.libraryFolders {
            try Task.checkCancellation()
            let folder = home.appendingPathComponent(path)
            guard let names = try? fm.contentsOfDirectory(atPath: folder.path) else { continue }
            for name in names {
                guard let id = Self.bundleID(fromEntryName: name)?.lowercased() else { continue }
                if id.hasPrefix("com.apple.") { continue }
                if Self.isInstalled(id, installed: installed) { continue }

                let url = folder.appendingPathComponent(name)
                let stats = directoryStats(at: url)
                if stats.inaccessibleCount > 0 {
                    meta.inaccessibleCount += stats.inaccessibleCount
                    meta.errors.append(ScanError(path: url.path, reason: .permissionDenied))
                }
                guard stats.size > 0 else { continue }
                let modified = stats.newestModification
                let ageDays = Int(now.timeIntervalSince(modified) / 86_400)
                if modified != .distantPast && ageDays < Self.recentDays { continue }

                items.append(CleanupItem(
                    url: url,
                    size: stats.size,
                    category: "Orphaned App Data",
                    reason: .appLeftover(bundleID: id),
                    riskLevel: .review,
                    confidenceLevel: confidence,
                    lastModifiedDate: modified == .distantPast ? nil : modified,
                    sourceModule: .appUninstaller
                ))
            }
        }

        items.sort { $0.size > $1.size }
        if items.count > Self.maxItems { items = Array(items.prefix(Self.maxItems)) }
        meta.scannedCount = items.count
        meta.duration = Date().timeIntervalSince(started)

        guard !items.isEmpty else { return ([], meta) }
        let category = CleanupCategory(
            kind: .orphanedData,
            title: String(localized: "Leftovers of Uninstalled Apps"),
            subtitle: String(localized: "Matched by bundle identifier — check each one, nothing is pre-selected"),
            icon: "archivebox",
            sourceModule: .appUninstaller,
            items: items
        )
        return ([category], meta)
    }

    // MARK: - Helpers (pure, unit-tested)

    /// Extracts a bundle identifier from a Library entry name, or nil if the
    /// name does not look like one.
    static func bundleID(fromEntryName name: String) -> String? {
        var n = name
        for suffix in [".plist", ".savedState", ".binarycookies", ".sfl2", ".sfl3", ".lockfile"] where n.hasSuffix(suffix) {
            n.removeLast(suffix.count)
        }
        if n.hasPrefix("group.") {
            n.removeFirst("group.".count)
        } else if let dot = n.firstIndex(of: "."),
                  n[..<dot].count == 10,
                  n[..<dot].allSatisfy({ $0.isUppercase || $0.isNumber }) {
            // "<TEAMID>.com.vendor.app"
            n = String(n[n.index(after: dot)...])
        }
        let parts = n.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 3,
              let first = parts.first,
              knownTLDs.contains(first.lowercased()),
              parts.allSatisfy({ !$0.isEmpty }) else { return nil }
        return n
    }

    /// True if an installed app owns `id`: the same identifier, or `id` is one
    /// of its helpers/extensions (`<installed>.something`).
    static func isInstalled(_ id: String, installed: [String]) -> Bool {
        installed.contains { id == $0 || id.hasPrefix($0 + ".") }
    }

    /// Bundle identifiers of every app in the standard locations, Apple's included.
    static func installedBundleIDs() -> Set<String> {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let roots = [
            "/Applications", "/Applications/Utilities",
            "/System/Applications", "/System/Applications/Utilities",
            home.appendingPathComponent("Applications").path,
        ]
        var ids = Set<String>()
        func readApps(in folder: String, descend: Bool) {
            let names = (try? fm.contentsOfDirectory(atPath: folder)) ?? []
            for name in names {
                let path = folder + "/" + name
                if name.hasSuffix(".app") {
                    let plist = NSDictionary(contentsOfFile: path + "/Contents/Info.plist")
                    if let id = plist?["CFBundleIdentifier"] as? String { ids.insert(id) }
                } else if descend, !name.hasPrefix(".") {
                    var isDir: ObjCBool = false
                    if fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                        readApps(in: path, descend: false)
                    }
                }
            }
        }
        for root in roots { readApps(in: root, descend: true) }
        return ids
    }
}
