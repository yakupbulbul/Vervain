import SwiftUI
import Charts

struct DiskAnalyzerView: View {
    @Environment(DiskAnalyzerViewModel.self) private var vm
    @Environment(CleanupCoordinator.self) private var coord

    @State private var showLargeFiles = false

    var body: some View {
        VStack(spacing: 0) {
            FeatureToolbar(title: "Disk Analyzer",
                           subtitle: "Visualize what's using space in your home folder") {
                toolbarButtons
            }
            Divider().background(Color.white.opacity(0.08))
            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(red: 0.09, green: 0.09, blue: 0.14))
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private var toolbarButtons: some View {
        if vm.isAnalyzing {
            Button("Cancel") { vm.cancelAnalyze() }
                .buttonStyle(.bordered).foregroundStyle(.white)
        } else {
            HStack(spacing: 8) {
                if vm.state.isAnalyzing == false, vm.rootNode != nil {
                    Toggle("Large files", isOn: $showLargeFiles)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .help("Show largest files in a separate panel")
                    Text("Large files")
                        .font(.caption).foregroundStyle(.white.opacity(0.6))
                }
                Button(vm.rootNode != nil ? "Re-Analyze" : "Analyze") {
                    vm.analyze()
                }
                .buttonStyle(.borderedProminent).tint(.purple)
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
                .foregroundStyle(.white)
        }
    }

    private var idleView: some View {
        VStack(spacing: 28) {
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 76))
                .foregroundStyle(LinearGradient(colors: [.purple, .blue],
                                                startPoint: .top, endPoint: .bottom))
                .symbolEffect(.pulse)
            VStack(spacing: 8) {
                Text("Disk Space Analyzer").font(.title.bold())
                Text("Get a visual breakdown of what's taking up\nspace, then send big files to the review flow.")
                    .font(.body).foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }
            Button("Analyze Home Folder") { vm.analyze() }
                .buttonStyle(.borderedProminent).controlSize(.large).tint(.purple)
        }
        .padding(40)
    }

    private var analyzingView: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large).tint(.purple)
            Text("Analyzing home folder…").foregroundStyle(.white.opacity(0.6))
            Text("This can take a moment for large folders. You can cancel any time.")
                .font(.caption).foregroundStyle(.white.opacity(0.35))
        }
    }

    @ViewBuilder
    private var resultsView: some View {
        VStack(spacing: 0) {
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

    // MARK: - Drill-down (existing layout, refreshed)

    private var drillDownPane: some View {
        HSplitView {
            VStack(spacing: 0) {
                if !vm.breadcrumbs.isEmpty { breadcrumbBar }
                Divider().background(Color.white.opacity(0.08))
                ScrollView {
                    DiskPieChart(items: vm.chartItems) { node in
                        vm.drillDown(into: node)
                    }
                    .padding(20)
                }
            }
            .frame(minWidth: 280, maxWidth: 360)
            .background(Color(red: 0.09, green: 0.09, blue: 0.14))

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
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    Button(node.name) { vm.navigateToBreadcrumb(node) }
                        .buttonStyle(.plain)
                        .font(.system(size: 12,
                            weight: idx == vm.breadcrumbs.count - 1 ? .semibold : .regular))
                        .foregroundStyle(idx == vm.breadcrumbs.count - 1
                                         ? .white : .white.opacity(0.5))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
    }

    private var diskNodeList: some View {
        List {
            let children = vm.selectedNode?.children ?? []
            if children.isEmpty {
                Text("No items").foregroundStyle(.white.opacity(0.3))
                    .listRowBackground(Color.clear)
            } else {
                ForEach(children, id: \.id) { node in
                    DiskNodeRow(node: node,
                                parentSize: vm.selectedNode?.size ?? 1)
                        .listRowBackground(Color.white.opacity(0.04))
                        .listRowSeparatorTint(Color.white.opacity(0.07))
                        .onTapGesture {
                            if node.isDirectory { vm.drillDown(into: node) }
                        }
                }
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .background(Color(red: 0.09, green: 0.09, blue: 0.14))
    }

    // MARK: - Largest-files pane

    private var largeFilesPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Largest Files").font(.headline)
                Spacer()
                if !vm.selectedFileIDs.isEmpty {
                    Text("\(vm.selectedFileIDs.count) selected · \(vm.selectedLargeFilesSize.formattedBytes)")
                        .font(.caption).foregroundStyle(.orange)
                    Button("Send to Review") {
                        let cats = vm.buildLargeFileCleanupCategory()
                        coord.startReview(cats, title: "Review Large Files")
                    }
                    .buttonStyle(.borderedProminent).tint(.purple).controlSize(.small)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color.white.opacity(0.04))

            List(vm.largestFiles, id: \.id) { node in
                LargeFileRow(
                    node: node,
                    isSelected: vm.selectedFileIDs.contains(node.id),
                    onToggle: { vm.toggleLargeFile(node.id) }
                )
                .listRowBackground(
                    vm.selectedFileIDs.contains(node.id)
                        ? Color.purple.opacity(0.10)
                        : Color.white.opacity(0.04)
                )
                .listRowSeparatorTint(Color.white.opacity(0.07))
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
        }
    }

    // MARK: - Banners & stats

    private var inaccessibleBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill").foregroundStyle(.yellow)
            Text("\(vm.metadata.inaccessibleCount) folder\(vm.metadata.inaccessibleCount == 1 ? "" : "s") couldn't be read. Grant Full Disk Access for a complete picture.")
                .font(.caption).foregroundStyle(.white.opacity(0.7))
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Color.yellow.opacity(0.08))
    }

    private var statsBar: some View {
        HStack(spacing: 16) {
            stat("Folders", "\(vm.scannedFolders)")
            stat("Files", "\(vm.scannedFiles)")
            if vm.skippedSymlinks > 0 {
                stat("Symlinks skipped", "\(vm.skippedSymlinks)")
            }
            if vm.metadata.inaccessibleCount > 0 {
                stat("Inaccessible", "\(vm.metadata.inaccessibleCount)", color: .yellow)
            }
            Spacer()
            if vm.metadata.duration > 0 {
                Text(String(format: "%.1fs", vm.metadata.duration))
                    .font(.caption).foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Color(red: 0.09, green: 0.09, blue: 0.14))
    }

    private func stat(_ label: String, _ value: String, color: Color = .white) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.4))
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
                .foregroundStyle(node.isDirectory ? .yellow.opacity(0.8) : .white.opacity(0.35))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(node.name).font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white).lineLimit(1)
                    Spacer()
                    SizeBadge(bytes: node.size, color: node.category.color)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.07))
                        Capsule().fill(node.category.color.opacity(0.7))
                            .frame(width: max(4, geo.size.width * fraction))
                    }
                }
                .frame(height: 4)
            }

            if node.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.25))
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
                    .foregroundStyle(isSelected ? .purple : .white.opacity(0.3))
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)

            Image(systemName: "doc.fill")
                .foregroundStyle(.white.opacity(0.35))

            VStack(alignment: .leading, spacing: 1) {
                Text(node.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(CleanupItem.makeDisplayPath(url: node.url))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1).truncationMode(.middle)
            }

            Spacer()
            Text(node.size.formattedBytes)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(.orange)
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
