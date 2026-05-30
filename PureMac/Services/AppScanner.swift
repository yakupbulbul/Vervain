import Foundation

/// Scans installed applications and produces `AppInfo` records with
/// graded-confidence leftover detection.
///
/// **Safety guards**:
/// - Apple system apps (bundleID starting with `com.apple.`) are skipped.
/// - Apps outside the standard locations (`/Applications`,
///   `~/Applications`, `/Applications/Utilities`) are skipped.
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
        for root in roots {
            let entries = (try? fm.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            for entry in entries where entry.pathExtension == "app" {
                if seen.insert(entry).inserted {
                    bundles.append(entry)
                }
            }
        }

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

                guard let confidence = matchConfidence(
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

    private func matchConfidence(
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

        // LOW — substring match on bundleID or app name. Multi-word names
        // shorter than 4 chars are ignored to avoid false positives like
        // an app called "Mail" matching every "mail*" file.
        if appNameLow.count >= 4, nameLower.contains(appNameLow) {
            return .low
        }
        if nameLower.contains(bundleIDLow) {
            return .low
        }

        return nil
    }

    // MARK: - Private

    private func buildAppInfo(url: URL) async -> AppInfo? {
        guard let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier else { return nil }

        // Skip Apple system apps.
        if bundleID.lowercased().hasPrefix("com.apple.") {
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
            lastModifiedDate: modDate
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
        return allowed.contains(parent)
    }
}
