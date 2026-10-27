import Foundation

/// A Time Machine local snapshot, as reported by `tmutil`.
struct LocalSnapshot: Identifiable, Sendable, Equatable {
    /// The date stamp `tmutil` uses as the snapshot's name, e.g. `2026-10-27-001234`.
    let name: String
    let date: Date

    var id: String { name }

    /// Deleting a snapshot is permanent and needs administrator rights, so
    /// Vervain never does it. It hands the user the exact command instead.
    var deleteCommand: String { "sudo tmutil deletelocalsnapshots \(name)" }

    static let deleteAllCommand =
        "for d in $(tmutil listlocalsnapshotdates / | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}$'); do sudo tmutil deletelocalsnapshots \"$d\"; done"
}

enum LocalSnapshotParser {
    /// Parses the output of `tmutil listlocalsnapshotdates /`. Only lines that
    /// are exactly a date stamp are kept, so a name can never carry anything
    /// else into the copied shell command.
    static func parse(_ output: String, timeZone: TimeZone = .current) -> [LocalSnapshot] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"

        return output
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.range(of: #"^\d{4}-\d{2}-\d{2}-\d{6}$"#, options: .regularExpression) != nil }
            .compactMap { name in
                formatter.date(from: name).map { LocalSnapshot(name: name, date: $0) }
            }
            .sorted { $0.date > $1.date }
    }

    /// Space macOS can give back on its own when it needs room: what the system
    /// reports as available for important use, minus what is free right now.
    static func purgeableBytes(availableForImportantUse: Int64, available: Int64) -> Int64 {
        max(0, availableForImportantUse - available)
    }
}

struct LocalSnapshotsReport: Sendable {
    var snapshots: [LocalSnapshot]
    var purgeableBytes: Int64
    var errorMessage: String?
}

actor LocalSnapshotsService {

    func report(home: URL = FileManager.default.homeDirectoryForCurrentUser) async -> LocalSnapshotsReport {
        var report = LocalSnapshotsReport(snapshots: [], purgeableBytes: 0, errorMessage: nil)
        do {
            report.snapshots = LocalSnapshotParser.parse(try runTmutil())
        } catch {
            report.errorMessage = error.localizedDescription
        }
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        if let values = try? home.resourceValues(forKeys: keys),
           let available = values.volumeAvailableCapacity,
           let important = values.volumeAvailableCapacityForImportantUsage {
            report.purgeableBytes = LocalSnapshotParser.purgeableBytes(
                availableForImportantUse: important, available: Int64(available)
            )
        }
        return report
    }

    private func runTmutil() throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
        process.arguments = ["listlocalsnapshotdates", "/"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }
}
