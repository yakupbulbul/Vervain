import Foundation
import AppKit

/// The single chokepoint through which every cleanup action in the app runs.
///
/// **Invariants** (audited by code review, not by the compiler):
/// - The only deletion primitives used are `FileManager.trashItem` and
///   `NSWorkspace.recycle` (both move to the Trash) — no module anywhere in
///   the codebase should ever call `removeItem`, `unlink`, run AppleScript,
///   or shell-out to `rm`.
/// - Every item passes `isSafeToTrash` immediately before it is trashed.
/// - Cleanup work happens off the `@MainActor`.
/// - Cancellation is supported via `Task.checkCancellation`.
/// - Per-item failures are recorded, never silently swallowed.
actor CleanupService {

    /// Executes a cleanup batch. Only `isSelected` items inside each category
    /// are processed; the rest are ignored.
    ///
    /// - Parameter progress: optional callback fired on the actor as each
    ///   item is processed. The closure is `@Sendable` since it crosses
    ///   actor boundaries.
    func execute(
        _ categories: [CleanupCategory],
        progress: (@Sendable (CleanupProgress) -> Void)? = nil
    ) async throws -> CleanupResult {

        let allSelected = categories.flatMap { cat in cat.items.filter(\.isSelected) }
        let totalCount = allSelected.count
        let totalBytes = allSelected.reduce(Int64(0)) { $0 + $1.size }
        var freedBytes: Int64 = 0
        var trashed: [TrashedItem] = []
        var failures: [CleanupFailure] = []
        var cancelled = false
        let started = Date()
        let fm = FileManager.default

        for (idx, item) in allSelected.enumerated() {
            // Stop cleanly: what is already in the Trash is reported, not lost.
            if Task.isCancelled { cancelled = true; break }
            progress?(CleanupProgress(
                currentIndex: idx,
                totalCount: totalCount,
                currentItem: item,
                bytesFreed: freedBytes,
                totalBytes: totalBytes
            ))
            guard Self.isSafeToTrash(item.url),
                  Self.isSafeToTrash(Self.resolvingParentSymlinks(item.url)) else {
                failures.append(CleanupFailure(
                    item: item,
                    reason: .other(message: String(localized: "Protected location"))
                ))
                continue
            }
            guard !Self.hasChangedSinceScan(item) else {
                failures.append(CleanupFailure(
                    item: item,
                    reason: .other(message: String(localized: "Changed since the scan — scan again"))
                ))
                continue
            }
            guard !ExclusionList.isExcluded(item.url) else {
                failures.append(CleanupFailure(
                    item: item,
                    reason: .other(message: String(localized: "Excluded in Settings"))
                ))
                continue
            }

            let sizeNow = Self.currentSize(of: item)
            do {
                // Try FileManager first (works for user-owned files)
                var resulting: NSURL?
                try fm.trashItem(at: item.url, resultingItemURL: &resulting)
                freedBytes += sizeNow
                trashed.append(TrashedItem(item: item, size: sizeNow, trashURL: resulting as URL?))
            } catch {
                // Fall back to NSWorkspace, which can show a system auth
                // dialog for items in /Applications.
                do {
                    let trashURL = try await Self.trashViaWorkspace(item.url)
                    freedBytes += sizeNow
                    trashed.append(TrashedItem(item: item, size: sizeNow, trashURL: trashURL))
                } catch let err as NSError {
                    failures.append(CleanupFailure(
                        item: item,
                        reason: Self.mapError(err)
                    ))
                }
            }
        }

        // Final tick so consumers can show 100%.
        progress?(CleanupProgress(
            currentIndex: cancelled ? trashed.count + failures.count : totalCount,
            totalCount: totalCount,
            currentItem: nil,
            bytesFreed: freedBytes,
            totalBytes: totalBytes
        ))

        return CleanupResult(
            requestedCount: totalCount,
            successCount: trashed.count,
            failedCount: failures.count,
            requestedBytes: totalBytes,
            freedBytes: freedBytes,
            failures: failures,
            duration: Date().timeIntervalSince(started),
            trashed: trashed,
            wasCancelled: cancelled
        )
    }

    /// Size of what is about to be trashed. Regular files are re-measured so
    /// "freed" reflects the file as it is now; folders keep the scanned size
    /// (re-walking a large tree just to report a number would double the work).
    nonisolated static func currentSize(of item: CleanupItem) -> Int64 {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .totalFileAllocatedSizeKey]
        guard let rv = try? item.url.resourceValues(forKeys: keys),
              rv.isRegularFile == true,
              let size = rv.totalFileAllocatedSize else { return item.size }
        return Int64(size)
    }

    /// Moves an item to the Trash through `NSWorkspace`, which can prompt for
    /// authorization for items (e.g. in /Applications) that `FileManager`
    /// cannot trash. This replaces the former AppleScript/Finder fallback, so
    /// no script is built from file names and no Apple Events entitlement is
    /// needed under the hardened runtime.
    private static func trashViaWorkspace(_ url: URL) async throws -> URL? {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<URL?, Error>) in
            // Built here, outside any actor, so AppKit may call it on any queue.
            let done: @Sendable ([URL: URL], Error?) -> Void = { newURLs, error in
                if let error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume(returning: newURLs[url])
                }
            }
            Task { @MainActor in
                NSWorkspace.shared.recycle([url], completionHandler: done)
            }
        }
    }

    /// The item's location with symlinks in its *parent* folders resolved, so a
    /// symlinked directory cannot smuggle a protected path past the guard. The
    /// item itself is not followed: trashing a symlink only moves the link.
    nonisolated static func resolvingParentSymlinks(_ url: URL) -> URL {
        url.deletingLastPathComponent()
            .resolvingSymlinksInPath()
            .appendingPathComponent(url.lastPathComponent)
    }

    /// True if a regular file was modified after the scan recorded it, in
    /// which case the user reviewed something that is no longer what is on disk.
    nonisolated static func hasChangedSinceScan(_ item: CleanupItem) -> Bool {
        guard let scanned = item.lastModifiedDate,
              let rv = try? item.url.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey]),
              rv.isRegularFile == true,
              let current = rv.contentModificationDate else { return false }
        return current.timeIntervalSince(scanned) > 1
    }

    /// Last line of defence before anything is trashed. Scanners are expected
    /// to never produce these paths; this makes sure a bug or a stale item can
    /// never take out a protected location.
    nonisolated static func isSafeToTrash(
        _ url: URL,
        home: URL? = nil
    ) -> Bool {
        let home = home ?? FileManager.default.homeDirectoryForCurrentUser
        guard url.isFileURL else { return false }
        let path = url.standardizedFileURL.path
        let homePath = home.standardizedFileURL.path

        let protectedExact: Set<String> = [
            "/", "/Applications", "/Library", "/System", "/Users", "/Volumes",
            "/usr", "/bin", "/sbin", "/etc", "/var", "/private", "/opt",
            homePath,
            homePath + "/Library",
            homePath + "/Desktop",
            homePath + "/Documents",
            homePath + "/Downloads",
            homePath + "/Movies",
            homePath + "/Music",
            homePath + "/Pictures",
            homePath + "/.Trash",
        ]
        if protectedExact.contains(path) { return false }

        let protectedPrefixes = ["/System/", "/usr/", "/bin/", "/sbin/", "/etc/", "/private/etc/"]
        if protectedPrefixes.contains(where: { path.hasPrefix($0) }) { return false }

        return true
    }

    /// Map a Cocoa `NSError` to our user-friendly failure reason.
    private static func mapError(_ err: NSError) -> CleanupFailure.Reason {
        switch (err.domain, err.code) {
        case (NSCocoaErrorDomain, NSFileWriteNoPermissionError),
             (NSCocoaErrorDomain, NSFileReadNoPermissionError):
            return .permissionDenied
        case (NSCocoaErrorDomain, NSFileNoSuchFileError),
             (NSCocoaErrorDomain, NSFileReadNoSuchFileError):
            return .notFound
        case (NSCocoaErrorDomain, NSFileLockingError):
            return .fileInUse
        default:
            return .other(message: err.localizedDescription)
        }
    }
}

// MARK: - Result types

struct CleanupResult: Sendable {
    let requestedCount: Int
    let successCount: Int
    let failedCount: Int
    let requestedBytes: Int64
    let freedBytes: Int64
    let failures: [CleanupFailure]
    let duration: TimeInterval
    /// Everything that reached the Trash, with where it went, so it can be put back.
    var trashed: [TrashedItem] = []
    /// True if the user cancelled part-way; `trashed` still lists what was moved.
    var wasCancelled: Bool = false

    var allSucceeded: Bool { failedCount == 0 && !wasCancelled }
}

struct CleanupFailure: Sendable, Identifiable {
    let id = UUID()
    let item: CleanupItem
    let reason: Reason

    enum Reason: Sendable, Hashable {
        case permissionDenied
        case notFound
        case fileInUse
        case other(message: String)

        var displayText: String {
            switch self {
            case .permissionDenied:  return String(localized: "Permission denied")
            case .notFound:          return String(localized: "File no longer exists")
            case .fileInUse:         return String(localized: "File is in use")
            case .other(let m):      return m
            }
        }
    }
}

struct CleanupProgress: Sendable {
    let currentIndex: Int
    let totalCount: Int
    let currentItem: CleanupItem?
    let bytesFreed: Int64
    let totalBytes: Int64

    var fraction: Double {
        guard totalCount > 0 else { return 0 }
        return Double(currentIndex) / Double(totalCount)
    }
}
