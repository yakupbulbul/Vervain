import Foundation

actor AppScanner {

    // MARK: - Public API

    func scanInstalledApps() async throws -> [AppInfo] {
        let fm = FileManager.default
        let appsURL = URL(fileURLWithPath: "/Applications")
        guard let appURLs = try? fm.contentsOfDirectory(
            at: appsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let bundleURLs = appURLs.filter { $0.pathExtension == "app" }

        return try await withThrowingTaskGroup(of: AppInfo?.self) { group in
            for url in bundleURLs {
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
        ]

        let bundleIDLower = app.bundleID.lowercased()
        let appNameLower  = app.name.lowercased()

        var leftovers: [URL] = []
        for root in searchRoots {
            let contents = (try? fm.contentsOfDirectory(
                at: root, includingPropertiesForKeys: nil, options: []
            )) ?? []
            for item in contents {
                let itemName = item.lastPathComponent.lowercased()
                if itemName.contains(bundleIDLower) || itemName.contains(appNameLower) {
                    leftovers.append(item)
                }
            }
        }

        // Also look for plist files in ~/Library/Preferences
        let prefsURL = home.appendingPathComponent("Library/Preferences")
        let plists = (try? fm.contentsOfDirectory(
            at: prefsURL, includingPropertiesForKeys: nil, options: []
        )) ?? []
        for plist in plists where plist.pathExtension == "plist" {
            let name = plist.deletingPathExtension().lastPathComponent.lowercased()
            if name.contains(bundleIDLower) && !leftovers.contains(plist) {
                leftovers.append(plist)
            }
        }

        let leftoverSize = leftovers.reduce(Int64(0)) { $0 + directorySize(at: $1) }
        return AppInfo(
            id: app.id,
            name: app.name,
            bundleID: app.bundleID,
            url: app.url,
            bundleSize: app.bundleSize,
            leftoverFiles: leftovers,
            leftoverSize: leftoverSize,
            isSelected: app.isSelected
        )
    }

    func uninstall(_ app: AppInfo) async throws {
        let fm = FileManager.default
        // Move .app bundle to trash
        try fm.trashItem(at: app.url, resultingItemURL: nil)
        // Move all leftovers to trash
        for leftover in app.leftoverFiles {
            try? fm.trashItem(at: leftover, resultingItemURL: nil)
        }
    }

    // MARK: - Private

    private func buildAppInfo(url: URL) async -> AppInfo? {
        guard let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier else { return nil }
        let name = (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
                ?? (bundle.infoDictionary?["CFBundleName"] as? String)
                ?? url.deletingPathExtension().lastPathComponent
        let size = directorySize(at: url)
        return AppInfo.make(name: name, bundleID: bundleID, url: url, bundleSize: size)
    }
}
