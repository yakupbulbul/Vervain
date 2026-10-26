import SwiftUI

/// Universal review screen presented as a sheet over any module that wants
/// to clean files. Driven entirely by `CleanupCoordinator`.
struct CleanupReviewView: View {
    @Environment(CleanupCoordinator.self) private var coord

    @State private var expanded: Set<UUID> = []
    @State private var showAllItems: Set<UUID> = []
    @State private var filter = ReviewFilter()
    @FocusState private var searchFocused: Bool

    private static let maxVisibleItems = 200

    /// Tracks the last non-idle state so the sheet content stays visible
    /// during the dismiss animation (prevents the "blank flash" bug where
    /// state flips to .idle before the sheet has finished sliding away).
    @State private var displayedState: CleanupCoordinator.State = .reviewing

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Theme.divider)

            switch displayedState {
            case .reviewing:
                reviewBody
            case .confirming:
                CleanupConfirmationSheet()
            case .executing:
                CleanupProgressView()
            case .done:
                CleanupDoneView()
            case .idle:
                EmptyView()
            }
        }
        .frame(width: 720, height: 560)
        .background(Theme.background)
        .foregroundStyle(Theme.textPrimary)
        .onAppear {
            displayedState = .reviewing
            showAllItems = []
            // Auto-expand first category only if it has a manageable number of items
            if let first = coord.categories.first, first.items.count <= Self.maxVisibleItems {
                expanded = [first.id]
            } else {
                expanded = []
            }
        }
        .onChange(of: coord.state) { _, new in
            if new != .idle {
                displayedState = new
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(coord.presentationTitle)
                .font(.title3.bold())
            Spacer()
            if displayedState == .reviewing {
                Menu("Select") {
                    Button("Only Safe Items") { coord.selectOnlySafe() }
                    Button("Clear Selection") { coord.clearSelection() }
                    Divider()
                    Button("Reset Defaults") { coord.resetToDefaults() }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .foregroundStyle(Theme.textPrimary)
            }
            Button {
                coord.cancel()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(6)
                    .background(Theme.divider, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
    }

    // MARK: - Search / sort / filter

    private var filterBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.textMuted)
            TextField("Search name or path", text: $filter.query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .accessibilityIdentifier("review-search")
            if !filter.query.isEmpty {
                Button { filter.query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
            Picker("Type", selection: $filter.kind) {
                ForEach(ReviewFilter.FileKind.allCases) { Text($0.label).tag($0) }
            }
            .labelsHidden().fixedSize()
            Picker("Sort", selection: $filter.sort) {
                ForEach(ReviewFilter.Sort.allCases) { Text($0.label).tag($0) }
            }
            .labelsHidden().fixedSize()
            // ⌘F focuses the search field.
            Button { searchFocused = true } label: { EmptyView() }
                .keyboardShortcut("f", modifiers: .command)
                .frame(width: 0, height: 0).opacity(0)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Theme.surfaceOverlay)
    }

    // MARK: - Review body

    private var reviewBody: some View {
        VStack(spacing: 0) {
            filterBar
            Divider().background(Theme.divider)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(coord.categories) { category in
                        let matching = filter.apply(to: category.items)
                        if !filter.isActive || !matching.isEmpty {
                            categoryHeader(category, matching: matching)
                            if expanded.contains(category.id) || filter.isActive {
                                let showAll = showAllItems.contains(category.id)
                                let visible = showAll
                                    ? matching
                                    : Array(matching.prefix(Self.maxVisibleItems))
                                ForEach(visible) { item in
                                    CleanupItemRow(item: item) {
                                        coord.toggleItem(categoryID: category.id, itemID: item.id)
                                    }
                                    .background(Theme.surfaceOverlay)
                                    Divider().background(Theme.divider)
                                }
                                if !showAll && matching.count > Self.maxVisibleItems {
                                    showMoreButton(category: category, total: matching.count)
                                }
                            }
                        }
                    }
                }
            }
            Divider().background(Theme.divider)
            footer
        }
    }

    private func showMoreButton(category: CleanupCategory, total: Int) -> some View {
        let remaining = total - Self.maxVisibleItems
        return Button {
            showAllItems.insert(category.id)
        } label: {
            HStack {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(Theme.smartScanAccent)
                Text("Show \(remaining) more items…")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Theme.surfaceOverlay)
    }

    private func categoryHeader(_ category: CleanupCategory, matching: [CleanupItem]) -> some View {
        let isOpen = expanded.contains(category.id) || filter.isActive
        return HStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isOpen { expanded.remove(category.id) }
                    else      { expanded.insert(category.id) }
                }
            } label: {
                Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 16)
            }
            .buttonStyle(.plain)

            Button {
                if filter.isActive {
                    // Only touch what the filter is showing.
                    let ids = Set(matching.map(\.id))
                    coord.setSelected(!matching.allSatisfy(\.isSelected), ids: ids)
                } else {
                    coord.toggleCategory(category.id)
                }
            } label: {
                Image(systemName: category.allSelected
                      ? "checkmark.circle.fill"
                      : (category.noneSelected ? "circle" : "minus.circle.fill"))
                    .foregroundStyle(
                        category.allSelected || !category.noneSelected
                            ? Theme.smartScanAccent : Theme.textMuted
                    )
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select category \(category.title)")

            Image(systemName: category.icon)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(category.title)
                    .font(.system(size: 13, weight: .semibold))
                Text("\(category.itemCount) items · \(category.selectedSize.formattedBytes) selected of \(category.totalSize.formattedBytes)")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textMuted)
            }
            Spacer()
            if !category.noneSelected && category.maxSelectedRisk > .safe {
                riskPill(category.maxSelectedRisk)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Theme.surfaceOverlay)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isOpen { expanded.remove(category.id) }
                else      { expanded.insert(category.id) }
            }
        }
    }

    @ViewBuilder
    private func riskPill(_ risk: CleanupRiskLevel) -> some View {
        HStack(spacing: 3) {
            Image(systemName: risk.icon).font(.system(size: 8, weight: .bold))
            Text(risk.label).font(.system(size: 9, weight: .semibold))
        }
        .padding(.horizontal, 5).padding(.vertical, 2)
        .foregroundStyle(risk.color)
        .background(risk.color.opacity(0.15), in: Capsule())
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(coord.totalSelectedCount) items selected")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
                if coord.totalSelectedCount == 0 {
                    Text("Select items above to clean")
                        .font(.caption).foregroundStyle(Theme.textMuted)
                } else {
                    Text(coord.totalSelectedSize.formattedBytes)
                        .font(.title3.bold()).foregroundStyle(Theme.systemJunkAccent)
                }
            }
            // Inline risk summary
            if coord.hasAnyRiskySelected || coord.hasAnyReviewSelected {
                VStack(alignment: .leading, spacing: 2) {
                    if coord.hasAnyRiskySelected {
                        Label("\(coord.riskyItems.count) risky", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(Theme.statusRisky)
                    }
                    if coord.hasAnyReviewSelected {
                        Label("\(coord.reviewItems.count) review", systemImage: "exclamationmark.circle.fill")
                            .font(.caption).foregroundStyle(Theme.statusReview)
                    }
                }
            }
            Spacer()
            Button("Cancel") { coord.cancel() }
                .buttonStyle(.bordered).foregroundStyle(Theme.textPrimary)
                .keyboardShortcut(.cancelAction)
            Button(coord.hasAnyRiskySelected || coord.hasAnyReviewSelected
                   ? "Continue…" : "Clean \(coord.totalSelectedSize.compactBytes)") {
                coord.confirm()
            }
            .buttonStyle(.borderedProminent).tint(Theme.systemJunkAccent)
            .keyboardShortcut(.defaultAction)
            .disabled(coord.totalSelectedSize == 0)
            .accessibilityIdentifier("review-confirm")
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
    }
}
