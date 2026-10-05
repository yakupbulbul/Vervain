import Foundation

/// Thresholds for the Large & Old Files module.
struct LargeFilesConfig: Sendable, Equatable {
    var minSizeBytes: Int64
    var minAgeDays: Int

    static let sizeKey = "largeFilesMinSizeMB"
    static let ageKey = "largeFilesMinAgeDays"
    static let defaultMinSizeMB = 100
    static let defaultMinAgeDays = 180

    static func fromDefaults(_ defaults: UserDefaults = .standard) -> LargeFilesConfig {
        let mb = defaults.object(forKey: sizeKey) as? Int ?? defaultMinSizeMB
        let days = defaults.object(forKey: ageKey) as? Int ?? defaultMinAgeDays
        return LargeFilesConfig(minSizeBytes: Int64(max(1, mb)) * 1_000_000, minAgeDays: max(0, days))
    }
}

/// Finds big files in the user's personal folders that have not been
/// modified for a while. Everything it returns is user-owned data, so items
/// are `.review` and are never selected by default.
actor LargeFilesScanner {

    static let maxItems = 500

    func scan(
        config: LargeFilesConfig,
        roots: [URL] = personalFolderRoots(),
        now: Date = Date()
    ) async throws -> (categories: [CleanupCategory], metadata: ScanMetadata) {
        let started = Date()
        var meta = ScanMetadata()
        var items: [CleanupItem] = []

        for root in roots {
            let errors = try walkRegularFiles(
                at: root,
                keys: [.fileSizeKey, .contentModificationDateKey]
            ) { url, rv in
                let size = Int64(rv.fileSize ?? 0)
                guard size >= config.minSizeBytes else { return }
                let modified = rv.contentModificationDate ?? .distantPast
                let ageDays = max(0, Int(now.timeIntervalSince(modified) / 86_400))
                guard ageDays >= config.minAgeDays else { return }
                items.append(CleanupItem(
                    url: url,
                    size: size,
                    category: "Large & Old Files",
                    reason: .largeOldFile(ageDays: ageDays),
                    riskLevel: .review,
                    confidenceLevel: .medium,
                    lastModifiedDate: modified,
                    sourceModule: .largeOldFiles
                ))
            }
            meta.errors.append(contentsOf: errors)
            meta.inaccessibleCount += errors.count
        }

        items.sort { $0.size > $1.size }
        if items.count > Self.maxItems { items = Array(items.prefix(Self.maxItems)) }
        meta.scannedCount = items.count
        meta.duration = Date().timeIntervalSince(started)

        guard !items.isEmpty else { return ([], meta) }
        let category = CleanupCategory(
            kind: .largeFiles,
            title: String(localized: "Large & Old Files"),
            subtitle: String(localized: "Your own files — nothing is selected until you choose"),
            icon: "doc.badge.clock",
            sourceModule: .largeOldFiles,
            items: items
        )
        return ([category], meta)
    }
}
