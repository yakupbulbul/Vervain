import SwiftUI

struct AppDetailPanel: View {
    let app: AppInfo
    let isScanningLeftovers: Bool
    let onScanLeftovers: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                sizeBreakdown
                leftoversSection
            }
            .padding(24)
        }
        .background(Color.white.opacity(0.02))
    }

    private var header: some View {
        VStack(spacing: 14) {
            AppIconView(appURL: app.url)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)

            VStack(spacing: 4) {
                Text(app.name)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text(app.bundleID)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                if let dev = app.developer {
                    Text(dev)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.35))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var sizeBreakdown: some View {
        VStack(spacing: 10) {
            metaRow("Version", app.version ?? "—")
            metaRow("Bundle Size", app.bundleSize.formattedBytes)
            if app.leftoverScanned {
                metaRow("Leftover Size",
                        app.leftoverSize > 0
                            ? app.leftoverSize.formattedBytes
                            : "Clean",
                        valueColor: app.leftoverSize > 0 ? .orange : .green)
            }
            if let mod = app.lastModifiedDate {
                metaRow("Last Modified", mod.formatted(date: .abbreviated, time: .shortened))
            }
            Divider().background(Color.white.opacity(0.06))
            HStack {
                Text("Total Size").font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(app.totalSize.formattedBytes)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }

    private func metaRow(_ k: String, _ v: String, valueColor: Color = .white) -> some View {
        HStack {
            Text(k).font(.system(size: 12)).foregroundStyle(.white.opacity(0.45))
            Spacer()
            Text(v)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(valueColor)
        }
    }

    @ViewBuilder
    private var leftoversSection: some View {
        if !app.leftoverScanned {
            HStack(spacing: 10) {
                if isScanningLeftovers {
                    ProgressView().controlSize(.small).tint(.orange)
                    Text("Scanning leftover files…")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.6))
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Leftover Detection")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Scan ~/Library for caches, preferences, and support files left by this app.")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    Button("Scan") { onScanLeftovers() }
                        .buttonStyle(.borderedProminent).controlSize(.small).tint(.orange)
                }
            }
            .padding(14)
            .background(Color.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        } else if app.leftoverItems.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                    .font(.system(size: 20))
                VStack(alignment: .leading, spacing: 2) {
                    Text("No leftover files found")
                        .font(.system(size: 13, weight: .medium))
                    Text("This app has a clean footprint.")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.green.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        } else {
            groupedLeftovers
        }
    }

    private var groupedLeftovers: some View {
        let grouped = Dictionary(grouping: app.leftoverItems, by: \.confidenceLevel)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Leftover Files")
                    .font(.system(size: 12, weight: .bold))
                    .textCase(.uppercase).tracking(0.8)
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text("\(app.leftoverItems.count) items · \(app.leftoverSize.compactBytes)")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.orange)
            }

            ForEach(CleanupConfidenceLevel.allCases, id: \.self) { conf in
                if let items = grouped[conf], !items.isEmpty {
                    confidenceGroup(conf: conf, items: items)
                }
            }
        }
    }

    private func confidenceGroup(conf: CleanupConfidenceLevel,
                                 items: [CleanupItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(conf.color).frame(width: 8, height: 8)
                Text(headerText(for: conf))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(conf.color)
                Spacer()
                Text("\(items.count) · \(items.reduce(Int64(0)) { $0 + $1.size }.compactBytes)")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
            VStack(spacing: 2) {
                ForEach(items.prefix(10)) { item in
                    HStack(spacing: 8) {
                        Text(item.url.lastPathComponent)
                            .font(.system(size: 11)).lineLimit(1)
                        Spacer()
                        Text(item.size.compactBytes)
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(.vertical, 3).padding(.horizontal, 10)
                    .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))
                    .help(item.displayPath)
                }
                if items.count > 10 {
                    Text("and \(items.count - 10) more…")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.leading, 10).padding(.top, 2)
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10))
    }

    private func headerText(for c: CleanupConfidenceLevel) -> String {
        switch c {
        case .high:    return "High confidence"
        case .medium:  return "Medium confidence"
        case .low:     return "Low confidence"
        case .unknown: return "Unknown"
        }
    }
}
