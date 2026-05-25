import SwiftUI
import Charts

struct DiskAnalyzerView: View {
    @Environment(DiskAnalyzerViewModel.self) private var vm

    var body: some View {
        VStack(spacing: 0) {
            FeatureToolbar(title: "Disk Analyzer", subtitle: "Visualize your home folder") {
                toolbarButtons
            }

            Divider().background(Color.white.opacity(0.08))

            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(red: 0.09, green: 0.09, blue: 0.14))
        .foregroundStyle(.white)
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var toolbarButtons: some View {
        if vm.isAnalyzing {
            ProgressView().controlSize(.small).tint(.white)
        } else {
            Button(vm.state == .results ? "Re-Analyze" : "Analyze") {
                vm.analyze()
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var mainContent: some View {
        switch vm.state {
        case .idle:
            idleView
        case .analyzing:
            analyzingView
        case .results:
            resultsView
        }
    }

    private var idleView: some View {
        VStack(spacing: 28) {
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 76))
                .foregroundStyle(
                    LinearGradient(colors: [.purple, .blue], startPoint: .top, endPoint: .bottom)
                )
                .symbolEffect(.pulse)

            VStack(spacing: 8) {
                Text("Disk Space Analyzer")
                    .font(.title.bold())
                Text("Get a visual breakdown of what's\ntaking up space on your Mac.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }

            Button("Analyze Home Folder") { vm.analyze() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.purple)
        }
        .padding(40)
    }

    private var analyzingView: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large).tint(.purple)
            Text("Analyzing home folder…")
                .foregroundStyle(.white.opacity(0.6))
            Text("This may take a moment for large folders.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.35))
        }
    }

    private var resultsView: some View {
        HSplitView {
            // Left: chart + breadcrumbs
            VStack(spacing: 0) {
                if !vm.breadcrumbs.isEmpty {
                    breadcrumbBar
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    Divider().background(Color.white.opacity(0.08))
                }
                ScrollView {
                    DiskPieChart(items: vm.chartItems) { node in
                        vm.drillDown(into: node)
                    }
                    .padding(20)
                }
            }
            .frame(minWidth: 280, maxWidth: 360)
            .background(Color(red: 0.09, green: 0.09, blue: 0.14))

            // Right: directory list
            diskNodeList
                .frame(minWidth: 320)
        }
    }

    // MARK: - Breadcrumb

    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(vm.breadcrumbs.enumerated()), id: \.element.id) { idx, node in
                    if idx > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    Button(node.name) {
                        vm.navigateToBreadcrumb(node)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: idx == vm.breadcrumbs.count - 1 ? .semibold : .regular))
                    .foregroundStyle(idx == vm.breadcrumbs.count - 1 ? .white : .white.opacity(0.5))
                }
            }
        }
    }

    // MARK: - Node list

    private var diskNodeList: some View {
        List {
            let children = vm.selectedNode?.children ?? []
            if children.isEmpty {
                Text("No items")
                    .foregroundStyle(.white.opacity(0.3))
                    .listRowBackground(Color.clear)
            } else {
                ForEach(children, id: \.id) { node in
                    DiskNodeRow(
                        node: node,
                        parentSize: vm.selectedNode?.size ?? 1
                    )
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
}

// MARK: - Disk Node Row

struct DiskNodeRow: View {
    let node: DiskNode
    let parentSize: Int64

    private var fraction: Double {
        guard parentSize > 0 else { return 0 }
        return Double(node.size) / Double(parentSize)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            Image(systemName: node.isDirectory ? "folder.fill" : "doc.fill")
                .font(.system(size: 14))
                .foregroundStyle(node.isDirectory ? .yellow.opacity(0.8) : .white.opacity(0.35))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(node.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                    SizeBadge(bytes: node.size, color: node.category.color)
                }

                // Usage bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.07))
                        Capsule()
                            .fill(node.category.color.opacity(0.7))
                            .frame(width: max(4, geo.size.width * fraction))
                    }
                }
                .frame(height: 4)
            }

            if node.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.25))
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .cursor(node.isDirectory ? .pointingHand : .arrow)
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
