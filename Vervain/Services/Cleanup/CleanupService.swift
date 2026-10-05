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
        var successCount = 0
        var failures: [CleanupFailure] = []
        let started = Date()
        let fm = FileManager.default

        for (idx, item) in allSelected.enumerated() {
            try Task.checkCancellation()
            progress?(CleanupProgress(
                currentIndex: idx,
                totalCount: totalCount,
                currentItem: item,
                bytesFreed: freedBytes,
                totalBytes: totalBytes
            ))
            guard Self.isSafeToTrash(item.url) else {
                failures.append(CleanupFailure(
                    item: item,
                    reason: .other(message: String(localized: "Protected location"))
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
            do {
                // Try FileManager first (works for user-owned files)
                try fm.trashItem(at: item.url, resultingItemURL: nil)
                freedBytes += item.size
                successCount += 1
            } catch {
                // Fall back to NSWorkspace, which can show a system auth
                // dialog for items in /Applications.
                do {
                    try await Self.trashViaWorkspace(item.url)
                    freedBytes += item.size
                    successCount += 1
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
            currentIndex: totalCount,
            totalCount: totalCount,
            currentItem: nil,
            bytesFreed: freedBytes,
            totalBytes: totalBytes
        ))

        return CleanupResult(
            requestedCount: totalCount,
            successCount: successCount,
            failedCount: failures.count,
            requestedBytes: totalBytes,
            freedBytes: freedBytes,
            failures: failures,
            duration: Date().timeIntervalSince(started)
        )
    }

    /// Moves an item to the Trash through `NSWorkspace`, which can prompt for
    /// authorization for items (e.g. in /Applications) that `FileManager`
    /// cannot trash. This replaces the former AppleScript/Finder fallback, so
    /// no script is built from file names and no Apple Events entitlement is
    /// needed under the hardened runtime.
    private static func trashViaWorkspace(_ url: URL) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            NSWorkspace.shared.recycle([url]) { _, error in
                if let error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume()
                }
            }
        }
    }

    /// Last line of defence before anything is trashed. Scanners are expected
    /// to never produce these paths; this makes sure a bug or a stale item can
    /// never take out a protected location.
    nonisolated static func isSafeToTrash(
        _ url: URL,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> Bool {
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

    var allSucceeded: Bool { failedCount == 0 }
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
