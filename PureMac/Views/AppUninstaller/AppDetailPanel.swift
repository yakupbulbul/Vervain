import SwiftUI

/// Right-hand detail panel in the App Uninstaller. Shows the selected app's
/// metadata plus leftovers grouped by confidence — so the user can see at
/// a glance which suggestions are exact matches and which are guesses.
struct AppDetailPanel: View {
    let app: AppInfo
    let isScanningLeftovers: Bool
    let onScanLeftovers: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                metadataGrid
                leftoversSection
            }
            .padding(20)
        }
        .background(Color.white.opacity(0.02))
    }

    private var header: some View {
        HStack(spacing: 14) {
            AppIconView(appURL: app.url)
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name).font(.title3.bold())
                Text(app.bundleID).font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                if let dev = app.developer {
                    Text(dev).font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
    }

    private var metadataGrid: some View {
        VStack(spacing: 8) {
            metaRow("Version", app.version ?? "—")
            metaRow("Bundle Size", app.bundleSize.formattedBytes)
            if app.leftoverScanned {
                metaRow("Leftover Size",
                        app.leftoverSize > 0
                            ? app.leftoverSize.formattedBytes
                            : "Clean")
            }
            if let mod = app.lastModifiedDate {
                metaRow("Last Modified", mod.formatted(date: .abbreviated, time: .shortened))
            }
            metaRow("Total Size", app.totalSize.formattedBytes, accent: true)
        }
        .padding(14)
        .background(Color.white.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: 10))
    }

    private func metaRow(_ k: String, _ v: String, accent: Bool = false) -> some View {
        HStack {
            Text(k).font(.caption).foregroundStyle(.white.opacity(0.5))
            Spacer()
            Text(v)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(accent ? .orange : .white)
        }
    }

    @ViewBuilder
    private var leftoversSection: some View {
        if !app.leftoverScanned {
            // Prompt scan
            HStack(spacing: 10) {
                if isScanningLeftovers {
                    ProgressView().controlSize(.small).tint(.orange)
                    Text("Scanning leftover files…")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.6))
                } else {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.orange)
                    Text("Leftovers not yet scanned.")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Button("Scan Now") { onScanLeftovers() }
                        .buttonStyle(.borderedProminent).controlSize(.small).tint(.orange)
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.04),
                        in: RoundedRectangle(cornerRadius: 10))
        } else if app.leftoverItems.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                Text("No leftover files found.").font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
        } else {
            groupedLeftovers
        }
    }

    private var groupedLeftovers: some View {
        let grouped = Dictionary(grouping: app.leftoverItems,
                                 by: \.confidenceLevel)
        return VStack(alignment: .leading, spacing: 14) {
            Text("Leftover Files (\(app.leftoverItems.count))")
                .font(.caption.bold())
                .textCase(.uppercase).tracking(0.8)
                .foregroundStyle(.white.opacity(0.5))

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
                    .font(.caption.bold())
                    .foregroundStyle(conf.color)
                Text("· \(items.count) item\(items.count == 1 ? "" : "s") · \(items.reduce(Int64(0)) { $0 + $1.size }.compactBytes)")
                    .font(.caption).foregroundStyle(.white.opacity(0.5))
                Spacer()
            }
            VStack(spacing: 2) {
                ForEach(items) { item in
                    HStack(spacing: 8) {
                        Text(item.url.lastPathComponent)
                            .font(.system(size: 12)).lineLimit(1)
                        Spacer()
                        Text(item.size.compactBytes)
                            .font(.caption).foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.vertical, 3).padding(.horizontal, 10)
                    .background(Color.white.opacity(0.03),
                                in: RoundedRectangle(cornerRadius: 6))
                    .help(item.displayPath)
                }
            }
        }
    }

    private func headerText(for c: CleanupConfidenceLevel) -> String {
        switch c {
        case .high:    return "High confidence (auto-selected for review)"
        case .medium:  return "Medium confidence (review carefully)"
        case .low:     return "Low confidence (manual choice required)"
        case .unknown: return "Unknown"
        }
    }
}
