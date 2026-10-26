import Foundation
import CoreServices

/// Scans installed applications and produces `AppInfo` records with
/// graded-confidence leftover detection.
///
/// **Safety guards**:
/// - Protected Apple apps (`com.apple.*`, except Xcode, iWork, GarageBand and
///   iMovie) are skipped.
/// - Apps outside the standard locations (`/Applications`,
///   `~/Applications`, `/Applications/Utilities`, or one vendor folder deep
///   such as `/Applications/Setapp`) are skipped.
/// - All deletion runs through `CleanupService` — this scanner only
///   identifies candidates.
actor AppScanner {

    // MARK: - Public API

    func scanInstalledApps() async throws -> [AppInfo] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let roots: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/Applications/Utilities"),
            home.appendingPathComponent("Applications")
        ]

        var seen = Set<URL>()
        var bundles: [URL] = []
        func collect(from root: URL, descend: Bool) {
            let entries = (try? fm.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            for entry in entries {
                if entry.pathExtension == "app" {
                    if seen.insert(entry).inserted { bundles.append(entry) }
                } else if descend,
                          entry.lastPathComponent != "Utilities",
                          (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                    // One level of vendor folders, e.g. /Applications/Setapp.
                    collect(from: entry, descend: false)
                }
            }
        }
        for root in roots { collect(from: root, descend: root.lastPathComponent != "Utilities") }

        return try await withThrowingTaskGroup(of: AppInfo?.self) { group in
            for url in bundles {
                group.addTask {
                    await self.buildAppInfo(url: url)
                }
            }
            var results: [AppInfo] = []
            for try await info in group {
                if let info { results.append(info) }
            }
            return results.sorted { $0.bundleSize > $1.bundleSize }
        }
    }

    /// Scans `~/Library` for files left behind by `app`, grading each match.
    /// Returns an updated `AppInfo` whose `leftoverItems` are all `CleanupItem`s.
    func scanLeftovers(for app: AppInfo) async -> AppInfo {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let searchRoots: [URL] = [
            home.appendingPathComponent("Library/Application Support"),
            home.appendingPathComponent("Library/Preferences"),
            home.appendingPathComponent("Library/Caches"),
            home.appendingPathComponent("Library/Containers"),
            home.appendingPathComponent("Library/Application Scripts"),
            home.appendingPathComponent("Library/Saved Application State"),
            home.appendingPathComponent("Library/Logs"),
            home.appendingPathComponent("Library/LaunchAgents"),
            home.appendingPathComponent("Library/Group Containers"),
            home.appendingPathComponent("Library/HTTPStorages"),
            home.appendingPathComponent("Library/WebKit"),
            home.appendingPathComponent("Library/Cookies"),
            home.appendingPathComponent("Library/Preferences/ByHost"),
            home.appendingPathComponent("Library/Application Support/CrashReporter"),
        ]

        let bundleID    = app.bundleID
        let bundleIDLow = bundleID.lowercased()
        let appNameLow  = app.name.lowercased()
        let vendorPrefix = bundleID.split(separator: ".").prefix(2)
            .joined(separator: ".").lowercased()  // "com.bohemiancoding"

        var items: [CleanupItem] = []
        for root in searchRoots {
            let contents = (try? fm.contentsOfDirectory(
                at: root, includingPropertiesForKeys: nil, options: []
            )) ?? []
            for url in contents {
                let nameLower = url.lastPathComponent.lowercased()
                let nameStem  = url.deletingPathExtension().lastPathComponent.lowercased()
                let parent    = url.deletingLastPathComponent().lastPathComponent

                guard let confidence = Self.matchConfidence(
                    nameLower: nameLower,
                    nameStem: nameStem,
                    parent: parent,
                    bundleIDLow: bundleIDLow,
                    appNameLow: appNameLow,
                    vendorPrefix: vendorPrefix
                ) else { continue }

                let size = directorySize(at: url)
                guard size > 0 else { continue }

                let risk: CleanupRiskLevel = confidence == .high ? .safe : .review
                items.append(CleanupItem(
                    url: url,
                    size: size,
                    category: "\(app.name) — Leftovers",
                    reason: .appLeftover(bundleID: bundleID),
                    riskLevel: risk,
                    confidenceLevel: confidence,
                    sourceModule: .appUninstaller
                ))
            }
        }

        var updated = app
        updated.leftoverItems = items
        updated.leftoverSize = items.reduce(0) { $0 + $1.size }
        return updated
    }

    // MARK: - Confidence matching

    static func matchConfidence(
        nameLower: String,
        nameStem: String,
        parent: String,
        bundleIDLow: String,
        appNameLow: String,
        vendorPrefix: String
    ) -> CleanupConfidenceLevel? {

        // HIGH — exact bundle ID match on filename, stem, or directory name.
        if nameStem == bundleIDLow || nameLower == bundleIDLow {
            return .high
        }
        // HIGH — Containers/<bundleID>
        if parent == "Containers", nameLower == bundleIDLow {
            return .high
        }

        // MEDIUM — vendor prefix (e.g. com.bohemiancoding) and contains app
        // name in the same path segment.
        if !vendorPrefix.isEmpty,
           nameLower.hasPrefix(vendorPrefix + "."),
           nameLower.contains(appNameLow) || nameStem.hasSuffix(appNameLow) {
            return .medium
        }
        // MEDIUM — name starts with bundleID (e.g. com.apple.Safari.LSSharedFileList.plist)
        if nameLower.hasPrefix(bundleIDLow + ".") {
            return .medium
        }

        // MEDIUM — shared group container: "group.<bundleID>" or "<TEAMID>.<bundleID>".
        if !bundleIDLow.isEmpty, nameLower.hasSuffix("." + bundleIDLow) {
            return .medium
        }

        // LOW — the app name as whole words, or the bundle ID as a substring.
        // Names shorter than 4 characters are ignored, and "mail" no longer
        // matches "mailchimp": the name must appear as separate words.
        if appNameLow.count >= 4, containsWholeWords(nameLower, appNameLow) {
            return .low
        }
        if nameLower.contains(bundleIDLow) {
            return .low
        }

        return nil
    }

    /// True if `needle`'s words appear consecutively, as whole words, in `haystack`.
    static func containsWholeWords(_ haystack: String, _ needle: String) -> Bool {
        let h = tokens(haystack)
        let n = tokens(needle)
        guard !n.isEmpty, n.count <= h.count else { return false }
        for start in 0...(h.count - n.count) where Array(h[start..<(start + n.count)]) == n {
            return true
        }
        return false
    }

    private static func tokens(_ text: String) -> [String] {
        text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    /// Apple apps the user may remove; everything else from Apple is protected.
    static let removableAppleBundleIDs: Set<String> = [
        "com.apple.dt.xcode",
        "com.apple.iwork.pages",
        "com.apple.iwork.numbers",
        "com.apple.iwork.keynote",
        "com.apple.garageband10",
        "com.apple.imovieapp",
    ]

    static func isProtectedAppleApp(bundleID: String) -> Bool {
        let id = bundleID.lowercased()
        return id.hasPrefix("com.apple.") && !removableAppleBundleIDs.contains(id)
    }

    private static func lastUsedDate(of url: URL) -> Date? {
        guard let item = MDItemCreateWithURL(nil, url as CFURL),
              let value = MDItemCopyAttribute(item, kMDItemLastUsedDate) else { return nil }
        return value as? Date
    }

    private static func source(of url: URL, bundleID: String) -> AppSource {
        if url.path.contains("/Setapp/") || bundleID.lowercased().hasPrefix("com.setapp.") { return .setapp }
        if FileManager.default.fileExists(atPath: url.appendingPathComponent("Contents/_MASReceipt/receipt").path) {
            return .appStore
        }
        return .other
    }

    // MARK: - Private

    private func buildAppInfo(url: URL) async -> AppInfo? {
        guard let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier else { return nil }

        // Skip protected Apple system apps (Safari, Mail, …).
        if Self.isProtectedAppleApp(bundleID: bundleID) {
            return nil
        }
        // Skip apps outside the standard locations.
        if !isAllowedAppLocation(url) {
            return nil
        }
        // Skip apps that have been moved to Trash.
        if url.pathComponents.contains(".Trash") {
            return nil
        }
        // Skip apps that no longer exist at their original location.
        if !FileManager.default.fileExists(atPath: url.path) {
            return nil
        }

        let info = bundle.infoDictionary
        let name = (info?["CFBundleDisplayName"] as? String)
                ?? (info?["CFBundleName"] as? String)
                ?? url.deletingPathExtension().lastPathComponent
        let version = (info?["CFBundleShortVersionString"] as? String)
                  ?? (info?["CFBundleVersion"] as? String)

        // Best-effort developer name — fall back to vendor reverse-DNS.
        let developer: String? = {
            if let copyright = info?["NSHumanReadableCopyright"] as? String,
               !copyright.isEmpty {
                return copyright
            }
            let comps = bundleID.split(separator: ".")
            if comps.count >= 2 {
                return String(comps[1]).capitalized
            }
            return nil
        }()

        let fm = FileManager.default
        let attrs = try? fm.attributesOfItem(atPath: url.path)
        let modDate = attrs?[.modificationDate] as? Date

        let size = directorySize(at: url)
        return AppInfo.make(
            name: name,
            bundleID: bundleID,
            version: version,
            developer: developer,
            url: url,
            bundleSize: size,
            lastModifiedDate: modDate,
            lastUsedDate: Self.lastUsedDate(of: url),
            source: Self.source(of: url, bundleID: bundleID),
            isAppleApp: bundleID.lowercased().hasPrefix("com.apple.")
        )
    }

    private func isAllowedAppLocation(_ url: URL) -> Bool {
        let parent = url.deletingLastPathComponent().standardizedFileURL.path
        let home = FileManager.default.homeDirectoryForCurrentUser
            .standardizedFileURL.path
        let allowed = [
            "/Applications",
            "/Applications/Utilities",
            home + "/Applications"
        ]
        if allowed.contains(parent) { return true }
        // One vendor folder deep, e.g. /Applications/Setapp/Foo.app
        let grandparent = URL(fileURLWithPath: parent).deletingLastPathComponent().path
        return grandparent == "/Applications" || grandparent == home + "/Applications"
    }
}
