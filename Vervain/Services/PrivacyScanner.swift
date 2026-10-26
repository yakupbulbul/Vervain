import Foundation

/// Finds browser caches, history and cookies for the browsers installed on
/// this Mac. Caches are safe to remove; history needs a look; cookies sign
/// you out of sites, so they are flagged risky and never pre-selected.
actor PrivacyScanner {

    private enum Kind { case cache, history, cookies }

    private struct Target {
        let browser: String
        let kind: Kind
        let url: URL
    }

    func scan(
        home: URL? = nil
    ) async throws -> (categories: [CleanupCategory], metadata: ScanMetadata) {
        let home = home ?? FileManager.default.homeDirectoryForCurrentUser
        let started = Date()
        var meta = ScanMetadata()
        var caches: [CleanupItem] = []
        var history: [CleanupItem] = []
        var cookies: [CleanupItem] = []

        for target in Self.targets(home: home) {
            try Task.checkCancellation()
            let fm = FileManager.default
            guard fm.fileExists(atPath: target.url.path) else { continue }
            guard fm.isReadableFile(atPath: target.url.path) else {
                meta.inaccessibleCount += 1
                meta.errors.append(ScanError(path: target.url.path, reason: .permissionDenied))
                continue
            }
            let stats = directoryStats(at: target.url)
            meta.inaccessibleCount += stats.inaccessibleCount
            guard stats.size > 0 else { continue }

            let label = target.url.lastPathComponent
            let modified = stats.newestModification == .distantPast ? nil : stats.newestModification
            switch target.kind {
            case .cache:
                caches.append(CleanupItem(
                    url: target.url, name: "\(target.browser) – \(label)", size: stats.size,
                    category: "Browser Caches", reason: .browserCache(browser: target.browser),
                    riskLevel: .safe, confidenceLevel: .high,
                    lastModifiedDate: modified, sourceModule: .privacy))
            case .history:
                history.append(CleanupItem(
                    url: target.url, name: "\(target.browser) – \(label)", size: stats.size,
                    category: "Browsing History", reason: .browserHistory(browser: target.browser),
                    riskLevel: .review, confidenceLevel: .medium,
                    lastModifiedDate: modified, sourceModule: .privacy))
            case .cookies:
                cookies.append(CleanupItem(
                    url: target.url, name: "\(target.browser) – \(label)", size: stats.size,
                    category: "Cookies", reason: .browserCookies(browser: target.browser),
                    riskLevel: .risky, confidenceLevel: .medium,
                    lastModifiedDate: modified, sourceModule: .privacy))
            }
        }

        meta.scannedCount = caches.count + history.count + cookies.count
        meta.duration = Date().timeIntervalSince(started)

        var cats: [CleanupCategory] = []
        if !caches.isEmpty {
            cats.append(CleanupCategory(
                kind: .browserCaches,
                title: String(localized: "Browser Caches"),
                subtitle: String(localized: "Pages and images that browsers re-download as needed"),
                icon: "safari", sourceModule: .privacy, items: caches.sorted { $0.size > $1.size }))
        }
        if !history.isEmpty {
            cats.append(CleanupCategory(
                kind: .browserHistory,
                title: String(localized: "Browsing History"),
                subtitle: String(localized: "Quit the browser first — you will lose your history"),
                icon: "clock.arrow.circlepath", sourceModule: .privacy, items: history.sorted { $0.size > $1.size }))
        }
        if !cookies.isEmpty {
            cats.append(CleanupCategory(
                kind: .browserCookies,
                title: String(localized: "Cookies"),
                subtitle: String(localized: "Removing cookies signs you out of websites"),
                icon: "lock.open", sourceModule: .privacy, items: cookies.sorted { $0.size > $1.size }))
        }
        return (cats, meta)
    }

    // MARK: - Browser locations

    private static func targets(home: URL) -> [Target] {
        var out: [Target] = []
        func add(_ browser: String, _ kind: Kind, _ relative: String) {
            out.append(Target(browser: browser, kind: kind, url: home.appendingPathComponent(relative)))
        }

        // Safari
        add("Safari", .cache, "Library/Caches/com.apple.Safari")
        add("Safari", .history, "Library/Safari/History.db")
        add("Safari", .cookies, "Library/Cookies/Cookies.binarycookies")

        // Firefox
        add("Firefox", .cache, "Library/Caches/Firefox")
        for profile in subfolders(of: home.appendingPathComponent("Library/Application Support/Firefox/Profiles")) {
            let base = "Library/Application Support/Firefox/Profiles/\(profile)"
            add("Firefox", .history, "\(base)/places.sqlite")
            add("Firefox", .cookies, "\(base)/cookies.sqlite")
        }

        // Chromium-based browsers
        let chromium: [(name: String, cache: String, support: String)] = [
            ("Chrome", "Library/Caches/Google/Chrome", "Library/Application Support/Google/Chrome"),
            ("Edge", "Library/Caches/Microsoft Edge", "Library/Application Support/Microsoft Edge"),
            ("Brave", "Library/Caches/BraveSoftware", "Library/Application Support/BraveSoftware/Brave-Browser"),
        ]
        for browser in chromium {
            add(browser.name, .cache, browser.cache)
            let support = home.appendingPathComponent(browser.support)
            for profile in subfolders(of: support) where profile == "Default" || profile.hasPrefix("Profile ") {
                let base = "\(browser.support)/\(profile)"
                add(browser.name, .history, "\(base)/History")
                add(browser.name, .cookies, "\(base)/Cookies")
                add(browser.name, .cookies, "\(base)/Network/Cookies")
            }
        }
        return out
    }

    private static func subfolders(of url: URL) -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
        return names.sorted()
    }
}
