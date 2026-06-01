import SwiftUI
import Charts

struct DiskAnalyzerView: View {
    @Environment(DiskAnalyzerViewModel.self) private var vm
    @Environment(CleanupCoordinator.self) private var coord
    @Environment(FullDiskAccessViewModel.self) private var fda

    @State private var showLargeFiles = false

    var body: some View {
        VStack(spacing: 0) {
            FeatureToolbar(title: "Disk Analyzer",
                           subtitle: "Visualize what's using space on your Mac") {
                toolbarButtons
            }
            Divider().background(Theme.divider)
            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.2), value: vm.isAnalyzing)
        }
        .background(Theme.background)
        .foregroundStyle(Theme.textPrimary)
    }

    @ViewBuilder
    private var toolbarButtons: some View {
        if vm.isAnalyzing {
            Button("Cancel") { vm.cancelAnalyze() }
                .buttonStyle(.bordered).foregroundStyle(Theme.textPrimary)
        } else {
            HStack(spacing: 8) {
                if case .results = vm.state {
                    Toggle("Large files", isOn: $showLargeFiles)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .help("Show largest files in a separate panel")
                    Text("Large files")
                        .font(.caption).foregroundStyle(Theme.textSecondary)
                }
                Button(vm.rootNode != nil ? "Re-Analyze" : "Analyze") {
                    vm.analyze()
                }
                .buttonStyle(.borderedProminent).tint(Theme.diskAnalyzerAccent)
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch vm.state {
        case .idle:        idleView
        case .analyzing:   analyzingView
        case .results:     resultsView
        case .error(let m):
            ContentUnavailableView("Analyze Failed",
                                   systemImage: "exclamationmark.triangle.fill",
                                   description: Text(m))
                .foregroundStyle(Theme.textPrimary)
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 28) {
            Image(systemName: "tree.fill")
                .font(.system(size: 76))
                .foregroundStyle(LinearGradient(colors: [Theme.diskAnalyzerAccent, Theme.smartScanAccent],
                                                startPoint: .top, endPoint: .bottom))
                .symbolEffect(.pulse)
            VStack(spacing: 8) {
                Text("Mac Storage Analyzer").font(.title.bold())
                Text("See exactly what is eating your storage —\nall folders, all top-level directories.")
                    .font(.body).foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Button("Analyze Mac Storage") { vm.analyze() }
                .buttonStyle(.borderedProminent).controlSize(.large).tint(Theme.diskAnalyzerAccent)
        }
        .padding(40)
    }

    // MARK: - Analyzing

    private var analyzingView: some View {
        VStack(spacing: 20) {
            ProgressView().controlSize(.extraLarge).tint(Theme.diskAnalyzerAccent)
            VStack(spacing: 6) {
                Text("Analyzing Mac Storage…").font(.headline)
                if !vm.scanningPath.isEmpty {
                    Text(vm.scanningPath)
                        .font(.caption).foregroundStyle(Theme.textSecondary)
                        .animation(.easeInOut(duration: 0.3), value: vm.scanningPath)
                }
            }
            Text("Scanning all directories concurrently. You can cancel any time.")
                .font(.caption2).foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)
            Button("Cancel") { vm.cancelAnalyze() }
                .buttonStyle(.bordered).foregroundStyle(Theme.textPrimary).controlSize(.small)
        }
        .padding(40)
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsView: some View {
        VStack(spacing: 0) {
            // Disk space usage bar
            if vm.diskTotalBytes > 0 {
                diskSpaceBar
                Divider().background(Theme.divider)
            }
            if vm.metadata.hasInaccessiblePaths {
                inaccessibleBanner
            }
            if showLargeFiles {
                largeFilesPane
            } else {
                drillDownPane
            }
            statsBar
        }
    }

    // MARK: - Disk space bar

    private var diskSpaceBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Macintosh HD", systemImage: "internaldrive.fill")
                    .font(.caption.bold()).foregroundStyle(Theme.textPrimary.opacity(0.8))
                Spacer()
                Text("\(vm.diskTotalBytes.formattedBytes) total")
                    .font(.caption2).foregroundStyle(Theme.textMuted)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.divider)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(
                            colors: [Theme.smartScanAccent, Theme.systemJunkAccent],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * usedFraction)
                }
            }
            .frame(height: 7)
            HStack {
                Text("\(vm.diskUsedBytes.formattedBytes) used")
                    .font(.caption).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(vm.diskFreeBytes.formattedBytes) available")
                    .font(.caption2).foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Theme.surfaceOverlay)
    }

    private var usedFraction: Double {
        guard vm.diskTotalBytes > 0 else { return 0 }
        return min(1.0, Double(vm.diskUsedBytes) / Double(vm.diskTotalBytes))
    }

    // MARK: - Drill-down

    private var drillDownPane: some View {
        HSplitView {
            VStack(spacing: 0) {
                if !vm.breadcrumbs.isEmpty { breadcrumbBar }
                Divider().background(Theme.divider)
                ScrollView {
                    DiskPieChart(items: vm.chartItems) { node in
                        vm.drillDown(into: node)
                    }
                    .padding(20)
                }
            }
            .frame(minWidth: 280, maxWidth: 360)
            .background(Theme.background)

            diskNodeList
                .frame(minWidth: 320)
        }
    }

    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(vm.breadcrumbs.enumerated()), id: \.element.id) { idx, node in
                    if idx > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textMuted)
                    }
                    Button(node.name) { vm.navigateToBreadcrumb(node) }
                        .buttonStyle(.plain)
                        .font(.system(size: 12,
                            weight: idx == vm.breadcrumbs.count - 1 ? .semibold : .regular))
                        .foregroundStyle(idx == vm.breadcrumbs.count - 1
                                         ? Theme.textPrimary : Theme.textSecondary)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
    }

    private var diskNodeList: some View {
        List {
            let children = vm.selectedNode?.children ?? []
            if children.isEmpty {
                VStack(spacing: 8) {
                    if vm.selectedNode?.name == "System & Other" {
                        Text("This space is used by macOS system data — APFS snapshots, virtual memory, firmware, and other protected resources that can't be individually listed.")
                            .foregroundStyle(Theme.textSecondary)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("No items").foregroundStyle(Theme.textMuted)
                    }
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(children, id: \.id) { node in
                    DiskNodeRow(node: node,
                                parentSize: vm.selectedNode?.size ?? 1)
                        .listRowBackground(Theme.surfaceOverlay)
                        .listRowSeparatorTint(Theme.divider)
                        .onTapGesture {
                            if node.isDirectory { vm.drillDown(into: node) }
                        }
                }
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
    }

    // MARK: - Largest-files pane

    private var largeFilesPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Largest Files").font(.headline)
                Spacer()
                if !vm.selectedFileIDs.isEmpty {
                    Text("\(vm.selectedFileIDs.count) selected · \(vm.selectedLargeFilesSize.formattedBytes)")
                        .font(.caption).foregroundStyle(Theme.systemJunkAccent)
                    Button("Send to Review") {
                        let cats = vm.buildLargeFileCleanupCategory()
                        coord.startReview(cats, title: "Review Large Files")
                    }
                    .buttonStyle(.borderedProminent).tint(Theme.diskAnalyzerAccent).controlSize(.small)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Theme.surfaceOverlay)

            List(vm.largestFiles, id: \.id) { node in
                LargeFileRow(
                    node: node,
                    isSelected: vm.selectedFileIDs.contains(node.id),
                    onToggle: { vm.toggleLargeFile(node.id) }
                )
                .listRowBackground(
                    vm.selectedFileIDs.contains(node.id)
                        ? Theme.diskAnalyzerAccent.opacity(0.10)
                        : Theme.surfaceOverlay
                )
                .listRowSeparatorTint(Theme.divider)
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
        }
    }

    // MARK: - Banners & stats

    private var inaccessibleBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill").foregroundStyle(Theme.fdaBannerAccent)
            Text(inaccessibleMessage)
                .font(.caption).foregroundStyle(Theme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Theme.fdaBannerBackground)
    }

    private var inaccessibleMessage: String {
        let count = vm.metadata.inaccessibleCount
        let folders = count == 1 ? "folder" : "folders"
        // With FDA denied, typically 50+ folders are inaccessible.
        // With FDA granted, only ~20-30 SIP-protected folders remain.
        if count <= 40 {
            return "\(count) system-protected \(folders) couldn't be read. This is normal — macOS protects these with SIP."
        } else {
            return "\(count) \(folders) couldn't be read. Grant Full Disk Access for a complete picture."
        }
    }

    private var statsBar: some View {
        HStack(spacing: 16) {
            stat("Folders", "\(vm.scannedFolders)")
            stat("Files", "\(vm.scannedFiles)")
            if vm.skippedSymlinks > 0 {
                stat("Symlinks skipped", "\(vm.skippedSymlinks)")
            }
            if vm.metadata.inaccessibleCount > 0 {
                stat("Inaccessible", "\(vm.metadata.inaccessibleCount)", color: Theme.fdaBannerAccent)
            }
            Spacer()
            if vm.metadata.duration > 0 {
                Text(String(format: "%.1fs", vm.metadata.duration))
                    .font(.caption).foregroundStyle(Theme.textMuted)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Theme.background)
    }

    private func stat(_ label: String, _ value: String, color: Color = Theme.textPrimary) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 9))
                .foregroundStyle(Theme.textMuted)
                .textCase(.uppercase).tracking(0.5)
            Text(value).font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(color)
        }
    }
}

// MARK: - Rows

struct DiskNodeRow: View {
    let node: DiskNode
    let parentSize: Int64

    private var fraction: Double {
        guard parentSize > 0 else { return 0 }
        return Double(node.size) / Double(parentSize)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: node.isDirectory ? "folder.fill" : "doc.fill")
                .font(.system(size: 14))
                .foregroundStyle(node.isDirectory ? Theme.systemJunkAccent.opacity(0.8) : Theme.textMuted)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(node.name).font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textPrimary).lineLimit(1)
                    Spacer()
                    SizeBadge(bytes: node.size, color: node.category.color)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.divider)
                        Capsule().fill(node.category.color.opacity(0.7))
                            .frame(width: max(4, geo.size.width * fraction))
                    }
                }
                .frame(height: 4)
            }

            if node.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10)).foregroundStyle(Theme.textFaint)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .cursor(node.isDirectory ? .pointingHand : .arrow)
    }
}

struct LargeFileRow: View {
    let node: DiskNode
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Theme.diskAnalyzerAccent : Theme.textMuted)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)

            Image(systemName: "doc.fill")
                .foregroundStyle(Theme.textMuted)

            VStack(alignment: .leading, spacing: 1) {
                Text(node.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(CleanupItem.makeDisplayPath(url: node.url))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Theme.textMuted)
                    .lineLimit(1).truncationMode(.middle)
            }

            Spacer()
            Text(node.size.formattedBytes)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.systemJunkAccent)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
    }
}

// MARK: - Cursor modifier

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        onHover { inside in
            if inside { cursor.push() } else { NSCursor.pop() }
        }
    }
}
