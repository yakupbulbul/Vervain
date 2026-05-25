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
                        .foregroundStyle(.white)
                } else {
                    Button("Scan Now") { vm.startScan() }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                }
            }

            Divider().background(Color.white.opacity(0.08))

            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(red: 0.09, green: 0.09, blue: 0.14))
        .foregroundStyle(.white)
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
                .foregroundStyle(.white)
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 32) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 80))
                .foregroundStyle(LinearGradient(colors: [.blue, .purple],
                                                startPoint: .top, endPoint: .bottom))
                .symbolEffect(.pulse)
            VStack(spacing: 8) {
                Text("Ready to Scan").font(.title.bold())
                Text("PureMac scans your caches, logs, language files,\napps, and disk usage — and explains every finding.")
                    .font(.body).foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }
            Button("Start Smart Scan") { vm.startScan() }
                .buttonStyle(.borderedProminent).controlSize(.large).tint(.blue)
        }
        .padding(40)
    }

    // MARK: - Scanning

    private var scanningView: some View {
        VStack(spacing: 40) {
            ScanningRingView(size: 180)
            Text("Analyzing your Mac…")
                .font(.title3).foregroundStyle(.white.opacity(0.7))
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
                        .font(.headline).foregroundStyle(.white.opacity(0.6))
                }
                .frame(width: 200)
            }

            // Headline + Review CTA
            VStack(alignment: .leading, spacing: 14) {
                if let bd = vm.breakdown {
                    Text(bd.explanation)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                }
                if vm.totalJunkBytes > 0 {
                    Text("We found \(vm.totalJunkBytes.formattedBytes) that can be reviewed and cleaned.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.65))
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
                    .buttonStyle(.borderedProminent).tint(.orange).controlSize(.large)
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
                    .font(.caption.bold()).foregroundStyle(.white.opacity(0.5))
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
                 color: .orange)
            Divider().frame(height: 30).overlay(Color.white.opacity(0.1))
            stat(label: "Disk Used",
                 value: String(format: "%.0f%%", vm.diskUsageFraction * 100),
                 color: vm.diskUsageFraction > 0.8 ? .red : .white)
            Divider().frame(height: 30).overlay(Color.white.opacity(0.1))
            stat(label: "Apps",
                 value: "\(vm.installedAppCount)",
                 color: .white)
            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }

    private func stat(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption).foregroundStyle(.white.opacity(0.5))
            Text(value).font(.title3.bold()).foregroundStyle(color)
        }
    }

    private var inaccessibleNote: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill").foregroundStyle(.yellow)
            Text("\(vm.scanMetadata.inaccessibleCount) folder\(vm.scanMetadata.inaccessibleCount == 1 ? " was" : "s were") inaccessible — grant Full Disk Access for complete results.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
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
