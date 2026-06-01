import SwiftUI

struct SmartScanView: View {
    @Environment(SmartScanViewModel.self) private var vm
    @Environment(CleanupCoordinator.self) private var coord

    /// Closure passed in from ContentView to switch the sidebar selection
    /// when a recommendation says "Open <module>".
    var onNavigate: ((AppFeature) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            FeatureToolbar(title: "Smart Scan", subtitle: "Check your Mac's health") {
                if vm.isScanning {
                    Button("Cancel") { vm.cancelScan() }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .foregroundStyle(Theme.textPrimary)
                } else {
                    Button("Scan Now") { vm.startScan() }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.smartScanAccent)
                }
            }

            Divider().background(Theme.divider)

            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.25), value: vm.isScanning)
        }
        .background(Theme.background)
        .foregroundStyle(Theme.textPrimary)
    }

    @ViewBuilder
    private var mainContent: some View {
        switch vm.state {
        case .idle:           idleView
        case .scanning:       scanningView
        case .results:        resultsView
        case .error(let m):
            ContentUnavailableView("Scan Failed",
                                   systemImage: "exclamationmark.triangle.fill",
                                   description: Text(m))
                .foregroundStyle(Theme.textPrimary)
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 32) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 80))
                .foregroundStyle(LinearGradient(colors: [Theme.smartScanAccent, Theme.diskAnalyzerAccent],
                                                startPoint: .top, endPoint: .bottom))
                .symbolEffect(.pulse)
            VStack(spacing: 8) {
                Text("Ready to Scan").font(.title.bold())
                Text("Vervain scans your caches, logs, language files,\napps, and disk usage — and explains every finding.")
                    .font(.body).foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Button("Start Smart Scan") { vm.startScan() }
                .buttonStyle(.borderedProminent).controlSize(.large).tint(Theme.smartScanAccent)
        }
        .padding(40)
    }

    // MARK: - Scanning

    private var scanningView: some View {
        VStack(spacing: 40) {
            ScanningRingView(size: 180)
            Text("Analyzing your Mac…")
                .font(.title3).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Results

    private var resultsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                topRow
                breakdownSection
                recommendationsSection
                summaryFooter
            }
            .padding(28)
        }
    }

    private var topRow: some View {
        HStack(alignment: .top, spacing: 32) {
            if let bd = vm.breakdown {
                VStack(spacing: 12) {
                    HealthRingView(score: vm.displayedScore, tier: bd.tier, size: 180)
                    Text("Health Score")
                        .font(.headline).foregroundStyle(Theme.textSecondary)
                }
                .frame(width: 200)
            }

            // Headline + Review CTA
            VStack(alignment: .leading, spacing: 14) {
                if let bd = vm.breakdown {
                    Text(bd.explanation)
                        .font(.title3.bold())
                        .foregroundStyle(Theme.textPrimary)
                }
                if vm.totalJunkBytes > 0 {
                    Text("We found \(vm.totalJunkBytes.formattedBytes) that can be reviewed and cleaned.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                if !vm.cleanupCategories.isEmpty {
                    Button {
                        coord.startReview(
                            vm.cleanupCategories,
                            title: "Review Smart Scan Findings"
                        )
                    } label: {
                        Label("Review Cleanup", systemImage: "checklist")
                    }
                    .buttonStyle(.borderedProminent).tint(Theme.systemJunkAccent).controlSize(.large)
                }
                if vm.scanMetadata.hasInaccessiblePaths {
                    inaccessibleNote
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var breakdownSection: some View {
        if let bd = vm.breakdown {
            HealthScoreBreakdownView(breakdown: bd)
        }
    }

    @ViewBuilder
    private var recommendationsSection: some View {
        if !vm.recommendations.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Recommended Actions")
                    .font(.caption.bold()).foregroundStyle(Theme.textSecondary)
                    .textCase(.uppercase).tracking(0.8)
                ForEach(vm.recommendations) { rec in
                    RecommendationCard(recommendation: rec) { action in
                        handle(action)
                    }
                }
            }
        }
    }

    private var summaryFooter: some View {
        HStack(spacing: 24) {
            stat(label: "Total Junk",
                 value: vm.totalJunkBytes.formattedBytes,
                 color: Theme.systemJunkAccent)
            Divider().frame(height: 30).overlay(Theme.divider)
            stat(label: "Disk Used",
                 value: String(format: "%.0f%%", vm.diskUsageFraction * 100),
                 color: vm.diskUsageFraction > 0.8 ? Theme.appUninstallerAccent : Theme.textPrimary)
            Divider().frame(height: 30).overlay(Theme.divider)
            stat(label: "Apps",
                 value: "\(vm.installedAppCount)",
                 color: Theme.textPrimary)
            Spacer()
        }
        .padding(16)
        .background(Theme.surfaceOverlay, in: RoundedRectangle(cornerRadius: 12))
    }

    private func stat(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption).foregroundStyle(Theme.textSecondary)
            Text(value).font(.title3.bold()).foregroundStyle(color)
        }
    }

    private var inaccessibleNote: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill").foregroundStyle(Theme.fdaBannerAccent)
            Text("\(vm.scanMetadata.inaccessibleCount) folder\(vm.scanMetadata.inaccessibleCount == 1 ? " was" : "s were") inaccessible — grant Full Disk Access for complete results.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: - Recommendation actions

    private func handle(_ action: SmartRecommendation.Action) {
        switch action {
        case .openCleanupReview(let cats, let title):
            coord.startReview(cats, title: title)
        case .openModule(let feature):
            onNavigate?(feature)
        }
    }
}
