import Foundation

/// Scans the user's home for cleanup candidates and emits them as
/// `CleanupCategory` instances with per-item risk/confidence already tagged.
/// All filesystem work happens on the actor — UI never blocks.
actor JunkScanner {

    /// Internal value returned by every category scanner.
    struct ScanProduct: Sendable {
        var categories: [CleanupCategory]
        var meta: ScanMetadata
    }

    // MARK: - Public API

    /// Performs a full scan across all System Junk categories including
    /// developer tools, containers, and other "System Data" paths.
    /// Returns categories whose items have already had selection policy applied.
    /// `metadata` reports scanned/inaccessible counts and any per-path errors.
    func scan() async throws -> (categories: [CleanupCategory], metadata: ScanMetadata) {
        let started = Date()

        async let caches     = scanUserCaches()
        async let logs       = scanLogs()
        async let langs      = scanLanguageFiles()
        async let trash      = scanTrash()
        async let downloads  = scanDownloads()
        async let systemData = scanSystemData()

        let results = try await [caches, logs, langs, trash, downloads, systemData]

        var allCategories: [CleanupCategory] = []
        var combined = ScanMetadata()
        for r in results {
            allCategories.append(contentsOf: r.categories)
            combined.scannedCount     += r.meta.scannedCount
            combined.skippedCount     += r.meta.skippedCount
            combined.inaccessibleCount += r.meta.inaccessibleCount
            combined.errors.append(contentsOf: r.meta.errors)
        }
        combined.duration = Date().timeIntervalSince(started)
        return (allCategories.filter { !$0.items.isEmpty }, combined)
    }

    // MARK: - User Caches

    private func scanUserCaches() async throws -> ScanProduct {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let base = home.appendingPathComponent("Library/Caches")
        let now = Date()
        var meta = ScanMetadata()

        var oldItems: [CleanupItem] = []
        var recentItems: [CleanupItem] = []

        try enumerate(at: base, meta: &meta, skipDirNames: Self.tccSensitiveCacheDirs) { url, attrs in
            let modified = attrs.contentModificationDate ?? attrs.creationDate ?? .distantPast
            let ageDays = max(0, Int(now.timeIntervalSince(modified) / 86_400))
            let size = Int64(attrs.fileSize ?? 0)
            guard size > 0 else { return }

            if ageDays > 30 {
                oldItems.append(CleanupItem(
                    url: url, size: size,
                    category: "User Caches",
                    reason: .oldCache(ageDays: ageDays),
                    riskLevel: .safe,
                    confidenceLevel: .high,
                    lastModifiedDate: modified,
                    sourceModule: .systemJunk
                ))
            } else {
                recentItems.append(CleanupItem(
                    url: url, size: size,
                    category: "User Caches",
                    reason: .recentCache,
                    riskLevel: .review,
                    confidenceLevel: .medium,
                    lastModifiedDate: modified,
                    sourceModule: .systemJunk
                ))
            }
        }
        meta.scannedCount = oldItems.count + recentItems.count

        var cats: [CleanupCategory] = []
        if !oldItems.isEmpty {
            cats.append(CleanupCategory(
                title: "Old Caches",
                subtitle: "Not accessed in over 30 days",
                icon: "internaldrive",
                sourceModule: .systemJunk,
                items: oldItems
            ))
        }
        if !recentItems.isEmpty {
            cats.append(CleanupCategory(
                title: "Recent Caches",
                subtitle: "Apps may regenerate these — review before removing",
                icon: "internaldrive.fill",
                sourceModule: .systemJunk,
                items: recentItems
            ))
        }
        return ScanProduct(categories: cats, meta: meta)
    }

    // MARK: - Logs

    private func scanLogs() async throws -> ScanProduct {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let base = home.appendingPathComponent("Library/Logs")
        let now = Date()
        var meta = ScanMetadata()

        var oldItems: [CleanupItem] = []
        var recentItems: [CleanupItem] = []

        try enumerate(at: base, meta: &meta) { url, attrs in
            let modified = attrs.contentModificationDate ?? attrs.creationDate ?? .distantPast
            let ageDays = max(0, Int(now.timeIntervalSince(modified) / 86_400))
            let size = Int64(attrs.fileSize ?? 0)
            guard size > 0 else { return }

            if ageDays > 7 {
                oldItems.append(CleanupItem(
                    url: url, size: size,
                    category: "Logs",
                    reason: .oldLog(ageDays: ageDays),
                    riskLevel: .safe,
                    confidenceLevel: .high,
                    lastModifiedDate: modified,
                    sourceModule: .systemJunk
                ))
            } else {
                recentItems.append(CleanupItem(
                    url: url, size: size,
                    category: "Logs",
                    reason: .recentLog,
                    riskLevel: .review,
                    confidenceLevel: .medium,
                    lastModifiedDate: modified,
                    sourceModule: .systemJunk
                ))
            }
        }
        meta.scannedCount = oldItems.count + recentItems.count

        var cats: [CleanupCategory] = []
        if !oldItems.isEmpty {
            cats.append(CleanupCategory(
                title: "Old Logs",
                subtitle: "Older than 7 days",
                icon: "doc.text.fill",
                sourceModule: .systemJunk,
                items: oldItems
            ))
        }
        if !recentItems.isEmpty {
            cats.append(CleanupCategory(
                title: "Recent Logs",
                subtitle: "May still be useful for diagnostics",
                icon: "doc.text",
                sourceModule: .systemJunk,
                items: recentItems
            ))
        }
        return ScanProduct(categories: cats, meta: meta)
    }

    // MARK: - Language Files

    private func scanLanguageFiles() async throws -> ScanProduct {
        let fm = FileManager.default
        let preferred = Set(Locale.preferredLanguages.map { lang -> String in
            String(lang.split(separator: "-").first ?? "").lowercased()
        })

        let appsRoot = URL(fileURLWithPath: "/Applications")
        let appBundles = (try? fm.contentsOfDirectory(
            at: appsRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        var items: [CleanupItem] = []
        for appURL in appBundles where appURL.pathExtension == "app" {
            try Task.checkCancellation()
            let resources = appURL.appendingPathComponent("Contents/Resources")
            let lprojDirs = (try? fm.contentsOfDirectory(
                at: resources,
                includingPropertiesForKeys: nil,
                options: []
            )) ?? []
            let appName = appURL.deletingPathExtension().lastPathComponent

            for lproj in lprojDirs where lproj.pathExtension == "lproj" {
                let langCode = lproj.deletingPathExtension().lastPathComponent
                if langCode == "Base" { continue }
                let baseLang = String(langCode.split(separator: "-").first ?? "").lowercased()
                if preferred.contains(baseLang) { continue }

                let size = directorySize(at: lproj)
                guard size > 0 else { continue }

                // Always review — removing .lproj invalidates the app signature.
                items.append(CleanupItem(
                    url: lproj,
                    name: "\(appName) – \(langCode)",
                    size: size,
                    category: "Language Files",
                    reason: .languageFile(language: langCode, app: appName),
                    riskLevel: .review,
                    confidenceLevel: .medium,
                    sourceModule: .systemJunk
                ))
            }
        }
        var meta = ScanMetadata()
        meta.scannedCount = items.count
        if items.isEmpty { return ScanProduct(categories: [], meta: meta) }
        let cats = [CleanupCategory(
            title: "Language Files",
            subtitle: "Removing these invalidates app code signatures — review carefully",
            icon: "globe",
            sourceModule: .systemJunk,
            items: items
        )]
        return ScanProduct(categories: cats, meta: meta)
    }

    // MARK: - System Data (developer caches, containers, package managers)

    private func scanSystemData() async throws -> ScanProduct {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let fm = FileManager.default
        var meta = ScanMetadata()

        struct SystemDataTarget {
            let path: String
            let title: String
            let reason: CleanupReason
            let risk: CleanupRiskLevel
            let confidence: CleanupConfidenceLevel
        }

        let targets: [SystemDataTarget] = [
            .init(path: "Library/Developer/Xcode/DerivedData",
                  title: "Xcode Build Cache",
                  reason: .custom("Xcode derived data — rebuilds automatically"),
                  risk: .safe, confidence: .high),
            .init(path: "Library/Developer/CoreSimulator/Caches",
                  title: "Simulator Caches",
                  reason: .custom("iOS Simulator caches — recreated on demand"),
                  risk: .safe, confidence: .high),
            .init(path: "Library/Developer/Xcode/iOS DeviceSupport",
                  title: "iOS Device Support",
                  reason: .custom("Debug symbols for connected devices — re-downloaded on next connect"),
                  risk: .review, confidence: .high),
            .init(path: "Library/Developer/Xcode/watchOS DeviceSupport",
                  title: "watchOS Device Support",
                  reason: .custom("Debug symbols for Apple Watch — re-downloaded on next connect"),
                  risk: .review, confidence: .high),
            .init(path: "Library/Developer/Xcode/Archives",
                  title: "Xcode Archives",
                  reason: .custom("Archived app builds — only needed for App Store submissions"),
                  risk: .risky, confidence: .high),
            .init(path: "Library/Caches/Homebrew",
                  title: "Homebrew Cache",
                  reason: .custom("Package manager download cache — re-downloaded on install"),
                  risk: .safe, confidence: .high),
            .init(path: "Library/Caches/pip",
                  title: "Python pip Cache",
                  reason: .custom("Python package cache — re-downloaded on install"),
                  risk: .safe, confidence: .high),
            .init(path: "Library/Caches/yarn",
                  title: "Yarn Cache",
                  reason: .custom("JavaScript package cache — re-downloaded on install"),
                  risk: .safe, confidence: .high),
            .init(path: ".npm/_cacache",
                  title: "npm Cache",
                  reason: .custom("Node.js package cache — re-downloaded on install"),
                  risk: .safe, confidence: .high),
            .init(path: "Library/Caches/CocoaPods",
                  title: "CocoaPods Cache",
                  reason: .custom("iOS dependency cache — re-downloaded on pod install"),
                  risk: .safe, confidence: .high),
            .init(path: "Library/Caches/org.carthage.CarthageKit",
                  title: "Carthage Cache",
                  reason: .custom("iOS dependency cache — re-downloaded on build"),
                  risk: .safe, confidence: .high),
            .init(path: "Library/Containers/com.docker.docker/Data",
                  title: "Docker Data",
                  reason: .custom("Docker images, containers, and volumes"),
                  risk: .risky, confidence: .high),
            .init(path: "Library/Android/sdk",
                  title: "Android SDK",
                  reason: .custom("Android development SDK — re-downloaded via SDK Manager"),
                  risk: .risky, confidence: .high),
            .init(path: "Library/Caches/com.apple.dt.Xcode",
                  title: "Xcode Internal Cache",
                  reason: .custom("Xcode internal caches — rebuilt automatically"),
                  risk: .safe, confidence: .high),
            .init(path: "Library/Developer/Xcode/UserData/IB Support",
                  title: "Interface Builder Cache",
                  reason: .custom("Interface Builder support files — recreated on demand"),
                  risk: .safe, confidence: .high),
        ]

        var devItems: [CleanupItem] = []
        var packageItems: [CleanupItem] = []

        for target in targets {
            try Task.checkCancellation()
            let url = home.appendingPathComponent(target.path)
            guard fm.fileExists(atPath: url.path) else { continue }

            let size = directorySize(at: url)
            guard size > 10_000_000 else { continue } // Skip < 10 MB

            let item = CleanupItem(
                url: url,
                size: size,
                category: "System Data",
                reason: target.reason,
                riskLevel: target.risk,
                confidenceLevel: target.confidence,
                sourceModule: .systemJunk
            )

            let isDev = target.path.contains("Developer") || target.path.contains("Android")
                     || target.path.contains("docker")
            if isDev {
                devItems.append(item)
            } else {
                packageItems.append(item)
            }
            meta.scannedCount += 1
        }

        var cats: [CleanupCategory] = []
        if !devItems.isEmpty {
            cats.append(CleanupCategory(
                title: "Developer Caches",
                subtitle: "Xcode, simulators, and dev tool data",
                icon: "hammer.fill",
                sourceModule: .systemJunk,
                items: devItems.sorted { $0.size > $1.size }
            ))
        }
        if !packageItems.isEmpty {
            cats.append(CleanupCategory(
                title: "Package Manager Caches",
                subtitle: "Homebrew, npm, pip, CocoaPods, and others",
                icon: "shippingbox.fill",
                sourceModule: .systemJunk,
                items: packageItems.sorted { $0.size > $1.size }
            ))
        }
        return ScanProduct(categories: cats, meta: meta)
    }

    // MARK: - Trash

    private func scanTrash() async throws -> ScanProduct {
        let trashURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".Trash")
        var meta = ScanMetadata()
        var items: [CleanupItem] = []
        try enumerate(at: trashURL, meta: &meta) { url, attrs in
            let size = Int64(attrs.fileSize ?? 0)
            guard size > 0 else { return }
            items.append(CleanupItem(
                url: url, size: size,
                category: "Trash",
                reason: .trashItem,
                riskLevel: .safe,
                confidenceLevel: .high,
                lastModifiedDate: attrs.contentModificationDate,
                sourceModule: .systemJunk
            ))
        }
        meta.scannedCount = items.count
        if items.isEmpty { return ScanProduct(categories: [], meta: meta) }
        return ScanProduct(
            categories: [CleanupCategory(
                title: "Trash Contents",
                subtitle: "Already in Trash — confirm to remove from disk",
                icon: "trash.fill",
                sourceModule: .systemJunk,
                items: items
            )],
            meta: meta
        )
    }

    // MARK: - Downloads

    private func scanDownloads() async throws -> ScanProduct {
        let downloads = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads")
        let fm = FileManager.default
        let now = Date()
        let installerExts: Set<String> = ["dmg", "pkg", "iso"]
        var meta = ScanMetadata()

        let entries = (try? fm.contentsOfDirectory(
            at: downloads,
            includingPropertiesForKeys: [
                .contentModificationDateKey, .fileSizeKey, .isDirectoryKey
            ],
            options: [.skipsHiddenFiles]
        )) ?? []

        var oldInstallers: [CleanupItem] = []
        var otherItems: [CleanupItem] = []

        for url in entries {
            try Task.checkCancellation()
            let rv = try? url.resourceValues(forKeys: [
                .contentModificationDateKey, .isDirectoryKey
            ])
            let modified = rv?.contentModificationDate ?? .distantPast
            let ageDays = max(0, Int(now.timeIntervalSince(modified) / 86_400))
            let isDir = rv?.isDirectory == true
            let size: Int64 = {
                if isDir { return directorySize(at: url) }
                let attrs = try? url.resourceValues(forKeys: [.fileSizeKey])
                return Int64(attrs?.fileSize ?? 0)
            }()
            guard size > 0 else { continue }
            let ext = url.pathExtension.lowercased()

            if ageDays > 30 && installerExts.contains(ext) {
                oldInstallers.append(CleanupItem(
                    url: url, size: size,
                    category: "Downloads",
                    reason: .oldDownload(ageDays: ageDays),
                    riskLevel: .review,
                    confidenceLevel: .medium,
                    lastModifiedDate: modified,
                    sourceModule: .systemJunk
                ))
            } else {
                otherItems.append(CleanupItem(
                    url: url, size: size,
                    category: "Downloads",
                    reason: ext.isEmpty ? .custom("Downloaded item") : .download(extension: ext),
                    riskLevel: .risky,
                    confidenceLevel: .low,
                    lastModifiedDate: modified,
                    sourceModule: .systemJunk
                ))
            }
        }
        meta.scannedCount = oldInstallers.count + otherItems.count

        var cats: [CleanupCategory] = []
        if !oldInstallers.isEmpty {
            cats.append(CleanupCategory(
                title: "Old Installers",
                subtitle: ".dmg / .pkg / .iso files older than 30 days",
                icon: "shippingbox.fill",
                sourceModule: .systemJunk,
                items: oldInstallers
            ))
        }
        if !otherItems.isEmpty {
            cats.append(CleanupCategory(
                title: "Other Downloads",
                subtitle: "User-owned files — never auto-selected",
                icon: "arrow.down.circle.fill",
                sourceModule: .systemJunk,
                items: otherItems
            ))
        }
        return ScanProduct(categories: cats, meta: meta)
    }

    // MARK: - Shared synchronous enumeration helper

    /// Walks `base` recursively, calling `handle` for each *regular file*.
    /// Records inaccessible directories into `meta` instead of throwing.
    /// Synchronous so it can be called from an `actor` method without colliding
    /// with the inout/sendable rules around `async let`.
    /// Directory names inside ~/Library/Caches that trigger TCC prompts for
    /// Media & Apple Music or Contacts — skip them entirely to avoid dialogs.
    private static let tccSensitiveCacheDirs: Set<String> = [
        "com.apple.Music",
        "com.apple.AMPLibraryAgent",
        "com.apple.AMPDevicesAgent",
        "com.apple.AppleMediaServices",
        "com.apple.AppleMediaServicesUI",
        "com.apple.AppleMediaServicesUIDynamicService",
        "com.apple.iTunesCloud",
        "com.apple.Contacts",
        "com.apple.AddressBook",
        "com.apple.AddressBookSourceSync",
    ]

    private func enumerate(
        at base: URL,
        meta: inout ScanMetadata,
        skipDirNames: Set<String> = [],
        handle: (URL, URLResourceValues) -> Void
    ) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: base.path) else { return }

        let keys: Set<URLResourceKey> = [
            .isRegularFileKey, .fileSizeKey,
            .contentModificationDateKey, .creationDateKey,
            .isSymbolicLinkKey, .isDirectoryKey
        ]

        // Box the meta counters so the @Sendable errorHandler can update them.
        // We're on the actor, so this is safe and the box is never shared.
        final class Box: @unchecked Sendable {
            var inaccessibleCount = 0
            var errors: [ScanError] = []
        }
        let box = Box()
        let errorHandler: (URL, Error) -> Bool = { url, _ in
            box.errors.append(ScanError(path: url.path, reason: .permissionDenied))
            box.inaccessibleCount += 1
            return true
        }

        guard let enumerator = fm.enumerator(
            at: base,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsPackageDescendants],
            errorHandler: errorHandler
        ) else { return }

        while let next = enumerator.nextObject() {
            try Task.checkCancellation()
            guard let url = next as? URL else { continue }

            // Skip TCC-sensitive directories and their descendants
            if !skipDirNames.isEmpty {
                let dirName = url.lastPathComponent
                if skipDirNames.contains(dirName) {
                    enumerator.skipDescendants()
                    meta.skippedCount += 1
                    continue
                }
            }

            guard let rv = try? url.resourceValues(forKeys: keys) else {
                meta.skippedCount += 1
                continue
            }
            guard rv.isSymbolicLink != true, rv.isRegularFile == true else { continue }
            handle(url, rv)
        }

        // Drain box back into meta now that enumeration is done.
        meta.inaccessibleCount += box.inaccessibleCount
        meta.errors.append(contentsOf: box.errors)
    }
}
