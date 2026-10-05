import Foundation
import CryptoKit

/// Finds byte-identical files in the user's personal folders.
///
/// Files are grouped by size, then by a hash of their first 64 KB, and only
/// the survivors are fully hashed. In every group the oldest file is kept and
/// is *never* offered for removal, so selecting every item still leaves one
/// copy of each file behind.
actor DuplicateScanner {

    static let minSizeBytes: Int64 = 1_000_000
    static let maxGroups = 300

    private struct Entry {
        let url: URL
        let size: Int64
        let modified: Date
    }

    func scan(
        roots: [URL]? = nil,
        minSize: Int64? = nil
    ) async throws -> (categories: [CleanupCategory], metadata: ScanMetadata) {
        let roots = roots ?? personalFolderRoots()
        let minSize = minSize ?? Self.minSizeBytes
        let started = Date()
        var meta = ScanMetadata()
        var bySize: [Int64: [Entry]] = [:]
        var seen = Set<String>()

        for root in roots {
            let errors = try walkRegularFiles(
                at: root,
                keys: [.fileSizeKey, .contentModificationDateKey]
            ) { url, rv in
                let size = Int64(rv.fileSize ?? 0)
                guard size >= minSize, seen.insert(url.path).inserted else { return }
                bySize[size, default: []].append(
                    Entry(url: url, size: size, modified: rv.contentModificationDate ?? .distantPast)
                )
            }
            meta.errors.append(contentsOf: errors)
            meta.inaccessibleCount += errors.count
        }
        meta.scannedCount = seen.count

        var groups: [[Entry]] = []
        for sizeGroup in bySize.values where sizeGroup.count > 1 {
            try Task.checkCancellation()

            var byPartial: [Data: [Entry]] = [:]
            for entry in sizeGroup {
                guard let digest = Self.digest(of: entry.url, partialOnly: true) else {
                    meta.skippedCount += 1
                    continue
                }
                byPartial[digest, default: []].append(entry)
            }

            for candidates in byPartial.values where candidates.count > 1 {
                var byFull: [Data: [Entry]] = [:]
                for entry in candidates {
                    try Task.checkCancellation()
                    guard let digest = Self.digest(of: entry.url, partialOnly: false) else {
                        meta.skippedCount += 1
                        continue
                    }
                    byFull[digest, default: []].append(entry)
                }
                groups.append(contentsOf: byFull.values.filter { $0.count > 1 })
            }
        }

        let ranked = groups
            .map { $0.sorted { $0.modified < $1.modified } }
            .sorted { wasted($0) > wasted($1) }
            .prefix(Self.maxGroups)

        let categories = ranked.map { group -> CleanupCategory in
            let keeper = group[0]
            let copies = group.dropFirst().map { copy in
                CleanupItem(
                    url: copy.url,
                    size: copy.size,
                    category: "Duplicates",
                    reason: .duplicate(of: keeper.url.lastPathComponent),
                    riskLevel: .review,
                    confidenceLevel: .medium,
                    lastModifiedDate: copy.modified,
                    sourceModule: .duplicates
                )
            }
            let keptIn = CleanupItem.makeDisplayPath(url: keeper.url.deletingLastPathComponent())
            return CleanupCategory(
                kind: .duplicates,
                title: keeper.url.lastPathComponent,
                subtitle: String(localized: "\(copies.count) copies · the oldest is kept in \(keptIn)"),
                icon: "square.on.square",
                sourceModule: .duplicates,
                items: Array(copies)
            )
        }

        meta.duration = Date().timeIntervalSince(started)
        return (categories, meta)
    }

    private func wasted(_ group: [Entry]) -> Int64 {
        (group.first?.size ?? 0) * Int64(group.count - 1)
    }

    private static func digest(of url: URL, partialOnly: Bool) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        do {
            if partialOnly {
                if let chunk = try handle.read(upToCount: 65_536) { hasher.update(data: chunk) }
            } else {
                while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
                    hasher.update(data: chunk)
                }
            }
        } catch {
            return nil
        }
        return Data(hasher.finalize())
    }
}
