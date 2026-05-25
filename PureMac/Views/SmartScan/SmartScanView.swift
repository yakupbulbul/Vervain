import SwiftUI

struct SmartScanView: View {
    @Environment(SmartScanViewModel.self) private var vm

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
                        .controlSize(.regular)
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
        case .idle:
            idleView
        case .scanning:
            scanningView
        case .results:
            resultsView
        case .error(let msg):
            ContentUnavailableView(
                "Scan Failed",
                systemImage: "exclamationmark.triangle.fill",
                description: Text(msg)
            )
            .foregroundStyle(.white)
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 32) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom)
                )
                .symbolEffect(.pulse)

            VStack(spacing: 8) {
                Text("Ready to Scan")
                    .font(.title.bold())
                Text("PureMac will check your caches, logs,\nlanguage files, apps, and disk usage.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }

            Button("Start Smart Scan") { vm.startScan() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.blue)
        }
        .padding(40)
    }

    // MARK: - Scanning

    private var scanningView: some View {
        VStack(spacing: 40) {
            ScanningRingView(size: 180)
            Text("Analyzing your Mac…")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Results

    private var resultsView: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 40) {
                // Left: ring
                if let score = vm.finalScore {
                    VStack(spacing: 16) {
                        HealthRingView(score: vm.displayedScore, tier: score.tier, size: 200)
                        Text("Health Score")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(width: 220)
                }

                // Right: breakdown
                summaryPanel
                    .frame(maxWidth: .infinity)
            }
            .padding(40)
        }
    }

    private var summaryPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Scan Results")
                .font(.title3.bold())
                .foregroundStyle(.white)

            // Junk categories
            VStack(spacing: 12) {
                ForEach(JunkCategoryType.allCases) { type in
                    let size = vm.junkSummary[type] ?? 0
                    HStack {
                        Image(systemName: type.icon)
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 20)
                        Text(type.rawValue)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.8))
                        Spacer()
                        SizeBadge(bytes: size, color: size > 0 ? .orange : .gray)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                }
            }

            // Totals
            Divider().background(Color.white.opacity(0.1))

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Junk")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                    Text(vm.totalJunkBytes.formattedBytes)
                        .font(.title3.bold())
                        .foregroundStyle(.orange)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Disk Used")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                    Text(String(format: "%.0f%%", vm.diskUsageFraction * 100))
                        .font(.title3.bold())
                        .foregroundStyle(vm.diskUsageFraction > 0.8 ? .red : .white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Apps")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                    Text("\(vm.installedAppCount)")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                }
            }
            .padding(.vertical, 4)
        }
        .padding(20)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
    }
}
