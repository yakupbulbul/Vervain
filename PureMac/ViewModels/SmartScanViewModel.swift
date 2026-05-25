import SwiftUI

@Observable
@MainActor
final class SmartScanViewModel {

    enum ScanState: Equatable {
        case idle
        case scanning
        case results
        case error(String)

        static func == (lhs: ScanState, rhs: ScanState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.scanning, .scanning), (.results, .results): return true
            case (.error(let l), .error(let r)): return l == r
            default: return false
            }
        }
    }

    var state: ScanState = .idle
    var displayedScore: Int = 0
    var finalScore: HealthScore?

    /// Per-category total sizes, keyed by category title (e.g. "Old Caches").
    var junkSummary: [(title: String, icon: String, size: Int64)] = []
    var totalJunkBytes: Int64 = 0
    var diskUsageFraction: Double = 0
    var installedAppCount: Int = 0
    var scanMetadata = ScanMetadata()

    /// Categories produced by the junk scan — used by Phase 4 to feed the
    /// universal review flow with pre-selected safe items.
    var cleanupCategories: [CleanupCategory] = []

    var isScanning: Bool { state == .scanning }

    private let junkScanner = JunkScanner()
    private let diskService = DiskAnalyzerService()
    private let appScanner  = AppScanner()
    private var scanTask: Task<Void, Never>?

    func startScan() {
        scanTask?.cancel()
        scanTask = Task { await performScan() }
    }

    func cancelScan() {
        scanTask?.cancel()
        state = .idle
    }

    private func performScan() async {
        state = .scanning
        displayedScore = 0

        do {
            async let junkResult = junkScanner.scan()
            async let fraction   = diskService.getDiskUsageFraction()
            async let apps       = appScanner.scanInstalledApps()

            let ((cats, meta), diskFraction, installedApps) =
                try await (junkResult, fraction, apps)

            guard !Task.isCancelled else { return }

            let total = cats.reduce(Int64(0)) { $0 + $1.totalSize }
            let summary = cats.map { (title: $0.title, icon: $0.icon, size: $0.totalSize) }

            let score = HealthScore.compute(
                junkBytes: total,
                diskUsageFraction: diskFraction,
                appCount: installedApps.count
            )

            cleanupCategories = cats
            junkSummary       = summary
            totalJunkBytes    = total
            diskUsageFraction = diskFraction
            installedAppCount = installedApps.count
            scanMetadata      = meta
            finalScore        = score
            state             = .results

            await animateScore(to: score.value)
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func animateScore(to target: Int) async {
        guard target > 0 else { return }
        let stepDelay: UInt64 = 1_500_000_000 / UInt64(target)
        for i in 1...target {
            guard !Task.isCancelled else { return }
            displayedScore = i
            try? await Task.sleep(nanoseconds: stepDelay)
        }
    }
}
