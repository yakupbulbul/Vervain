import SwiftUI
import Charts

struct DiskPieChart: View {
    let items: [DiskNode]
    var onSelect: ((DiskNode) -> Void)?

    @State private var selectedName: String?

    private var total: Int64 { items.reduce(0) { $0 + $1.size } }

    var body: some View {
        VStack(spacing: 20) {
            // Donut chart
            Chart(items, id: \.id) { node in
                SectorMark(
                    angle: .value("Size", max(node.size, 1)),
                    innerRadius: .ratio(0.55),
                    outerRadius: selectedName == node.name ? .ratio(0.97) : .ratio(0.90),
                    angularInset: 2.0
                )
                .foregroundStyle(by: .value("Name", node.name))
                .opacity(selectedName == nil || selectedName == node.name ? 1.0 : 0.45)
                .cornerRadius(4)
            }
            .chartForegroundStyleScale(
                domain: items.map(\.name),
                range: items.map(\.category.color)
            )
            .chartLegend(.hidden)
            .chartAngleSelection(value: $selectedName)
            .frame(height: 240)
            .animation(.spring(.snappy), value: selectedName)
            .onChange(of: selectedName) { _, newName in
                if let name = newName, let node = items.first(where: { $0.name == name }) {
                    onSelect?(node)
                }
            }

            // Legend
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 8
            ) {
                ForEach(items, id: \.id) { node in
                    legendRow(for: node)
                }
            }
        }
    }

    private func legendRow(for node: DiskNode) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(node.category.color)
                .frame(width: 9, height: 9)
            Text(node.name)
                .font(.caption)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(node.size.compactBytes)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(.snappy)) {
                selectedName = node.name
            }
            onSelect?(node)
        }
    }
}
