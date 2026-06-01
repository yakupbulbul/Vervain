import Foundation

/// Structured outcome of a scan: counts + per-error detail.
/// Surfaces inaccessible paths and permission failures honestly instead of
/// silently swallowing them.
struct ScanMetadata: Sendable {
    var scannedCount: Int = 0
    var skippedCount: Int = 0
    var inaccessibleCount: Int = 0
    var duration: TimeInterval = 0
    var errors: [ScanError] = []

    /// True if any folder was unreachable — typically a Full Disk Access hint.
    var hasInaccessiblePaths: Bool { inaccessibleCount > 0 }

    /// Convenience for displaying a one-line summary in the UI.
    var summary: String {
        var parts: [String] = ["Scanned \(scannedCount) items"]
        if inaccessibleCount > 0 { parts.append("\(inaccessibleCount) inaccessible") }
        if skippedCount > 0      { parts.append("\(skippedCount) skipped") }
        return parts.joined(separator: " · ")
    }
}

/// A single error encountered while scanning. Path is preserved so the user
/// can investigate which folder needs Full Disk Access.
struct ScanError: Sendable, Identifiable, Hashable {
    let id: UUID
    let path: String
    let reason: Reason

    enum Reason: Sendable, Hashable {
        case permissionDenied
        case notFound
        case ioError(message: String)
        case other(message: String)

        var displayText: String {
            switch self {
            case .permissionDenied:        return "Permission denied"
            case .notFound:                return "Path no longer exists"
            case .ioError(let msg):        return "I/O error: \(msg)"
            case .other(let msg):          return msg
            }
        }
    }

    init(path: String, reason: Reason) {
        self.id = UUID()
        self.path = path
        self.reason = reason
    }
}
