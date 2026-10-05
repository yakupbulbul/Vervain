import Foundation

/// Capacity of the startup volume. Read-only; no scanning involved.
struct DiskUsage: Sendable, Equatable {
    let total: Int64
    let available: Int64

    var used: Int64 { max(0, total - available) }

    var usedFraction: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(used) / Double(total)))
    }

    static func current(volume: URL = URL(fileURLWithPath: "/")) -> DiskUsage? {
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey
        ]
        guard let rv = try? volume.resourceValues(forKeys: keys),
              let total = rv.volumeTotalCapacity,
              let available = rv.volumeAvailableCapacityForImportantUsage else { return nil }
        return DiskUsage(total: Int64(total), available: available)
    }
}
