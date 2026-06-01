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
    var breakdown: HealthScoreBreakdown?

    /// Per-category total sizes, keyed by category title (e.g. "Old Caches").
    var junkSummary: [(title: String, icon: String, size: Int64)] = []
    var totalJunkBytes: Int64 = 0
    var diskUsageFraction: Double = 0
    var installedAppCount: Int = 0
    var scanMetadata = ScanMetadata()
    var recommendations: [SmartRecommendation] = []

    /// Categories produced by the junk scan — used to feed the universal
    /// review flow with pre-selected safe items.
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

    // MARK: - Scan

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

            // Old downloads contribution to the score breakdown
            let oldDownloadBytes = cats
                .filter { $0.title == "Old Installers" }
                .reduce(Int64(0)) { $0 + $1.totalSize }

            let breakdown = HealthScoreBreakdown.compute(
                junkBytes: total,
                diskUsageFraction: diskFraction,
                appCount: installedApps.count,
                leftoverCount: 0,
                oldDownloadBytes: oldDownloadBytes
            )

            cleanupCategories = cats
            junkSummary       = summary
            totalJunkBytes    = total
            diskUsageFraction = diskFraction
            installedAppCount = installedApps.count
            scanMetadata      = meta
            self.breakdown    = breakdown
            recommendations   = buildRecommendations(
                categories: cats,
                diskFraction: diskFraction,
                appCount: installedApps.count
            )
            state = .results

            await animateScore(to: breakdown.finalScore)
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    // MARK: - Recommendations

    /// Build the top-N actionable suggestions surfaced as cards in Smart Scan.
    /// Currently emits up to 3, prioritised by severity then recoverable size.
    private func buildRecommendations(
        categories: [CleanupCategory],
        diskFraction: Double,
        appCount: Int
    ) -> [SmartRecommendation] {

        var recs: [SmartRecommendation] = []

        // Critical: disk dangerously full.
        if diskFraction > 0.90 {
            recs.append(.init(
                title: "Disk Critically Full",
                description: "Your startup disk is over 90% full. Review and remove cached files and old downloads.",
                severity: .critical,
                sourceModule: .smartScan,
                action: .openCleanupReview(
                    categories: categories.filter { $0.sourceModule == .systemJunk },
                    title: "Free Disk Space"
                ),
                estimatedRecoverableBytes: categories.reduce(0) { $0 + $1.totalSize }
            ))
        } else if diskFraction > 0.80 {
            recs.append(.init(
                title: "Disk Getting Full",
                description: "Your startup disk is over 80% full. Cleaning system junk can free space.",
                severity: .warning,
                sourceModule: .smartScan,
                action: .openCleanupReview(
                    categories: categories.filter { $0.sourceModule == .systemJunk },
                    title: "Free Disk Space"
                ),
                estimatedRecoverableBytes: categories.reduce(0) { $0 + $1.totalSize }
            ))
        }

        // Caches recommendation (only if there's meaningful junk).
        let cacheCats = categories.filter {
            $0.title == "Old Caches" || $0.title == "Old Logs"
        }
        let cacheBytes = cacheCats.reduce(Int64(0)) { $0 + $1.totalSize }
        if cacheBytes > 500_000_000 {
            recs.append(.init(
                title: "Clean Old Caches & Logs",
                description: "Found \(cacheBytes.compactBytes) of caches and logs unused for a while. Safe to remove.",
                severity: cacheBytes > 5_000_000_000 ? .warning : .info,
                sourceModule: .systemJunk,
                action: .openCleanupReview(
                    categories: cacheCats,
                    title: "Clean Caches & Logs"
                ),
                estimatedRecoverableBytes: cacheBytes
            ))
        }

        // Old installers (.dmg/.pkg)
        if let installers = categories.first(where: { $0.title == "Old Installers" }),
           installers.totalSize > 200_000_000 {
            recs.append(.init(
                title: "Remove Old Installers",
                description: "Old .dmg / .pkg installers totalling \(installers.totalSize.compactBytes) — these can usually be re-downloaded.",
                severity: .info,
                sourceModule: .systemJunk,
                action: .openCleanupReview(
                    categories: [installers],
                    title: "Remove Old Installers"
                ),
                estimatedRecoverableBytes: installers.totalSize
            ))
        }

        // Lots of apps installed
        if appCount > 100 {
            recs.append(.init(
                title: "Review Installed Apps",
                description: "You have \(appCount) applications installed. Removing unused ones can free space and reduce background activity.",
                severity: .info,
                sourceModule: .appUninstaller,
                action: .openModule(.appUninstaller),
                estimatedRecoverableBytes: 0
            ))
        }

        // Sort: severity desc, then size desc; take top 3.
        return recs
            .sorted { lhs, rhs in
                if lhs.severity != rhs.severity { return lhs.severity > rhs.severity }
                return lhs.estimatedRecoverableBytes > rhs.estimatedRecoverableBytes
            }
            .prefix(3)
            .map { $0 }
    }

    // MARK: - Score animation

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
