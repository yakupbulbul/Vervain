import Foundation

extension Int64 {
    /// Returns a human-readable byte count string (Finder-style: 1 KB = 1000 bytes).
    var formattedBytes: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }

    /// Returns a compact byte count string for badges (e.g. "1.2 GB").
    var compactBytes: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.includesActualByteCount = false
        return formatter.string(fromByteCount: self)
    }
}
