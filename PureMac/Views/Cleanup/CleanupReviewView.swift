import SwiftUI

/// Universal review screen presented as a sheet over any module that wants
/// to clean files. Driven entirely by `CleanupCoordinator`.
struct CleanupReviewView: View {
    @Environment(CleanupCoordinator.self) private var coord

    @State private var expanded: Set<UUID> = []
    @State private var showAllItems: Set<UUID> = []

    private static let maxVisibleItems = 200

    /// Tracks the last non-idle state so the sheet content stays visible
    /// during the dismiss animation (prevents the "blank flash" bug where
    /// state flips to .idle before the sheet has finished sliding away).
    @State private var displayedState: CleanupCoordinator.State = .reviewing

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color.white.opacity(0.08))

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
        .background(Color(red: 0.09, green: 0.09, blue: 0.14))
        .foregroundStyle(.white)
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
                Button("Reset Defaults") { coord.resetToDefaults() }
                    .buttonStyle(.bordered).controlSize(.small)
                    .foregroundStyle(.white)
            }
            Button {
                coord.cancel()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(6)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
    }

    // MARK: - Review body

    private var reviewBody: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(coord.categories) { category in
                        categoryHeader(category)
                        if expanded.contains(category.id) {
                            let showAll = showAllItems.contains(category.id)
                            let visible = showAll
                                ? category.items
                                : Array(category.items.prefix(Self.maxVisibleItems))
                            ForEach(visible) { item in
                                CleanupItemRow(item: item) {
                                    coord.toggleItem(categoryID: category.id, itemID: item.id)
                                }
                                .background(Color.white.opacity(0.02))
                                Divider().background(Color.white.opacity(0.05))
                            }
                            if !showAll && category.items.count > Self.maxVisibleItems {
                                showMoreButton(category: category)
                            }
                        }
                    }
                }
            }
            Divider().background(Color.white.opacity(0.08))
            footer
        }
    }

    private func showMoreButton(category: CleanupCategory) -> some View {
        let remaining = category.items.count - Self.maxVisibleItems
        return Button {
            showAllItems.insert(category.id)
        } label: {
            HStack {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.blue)
                Text("Show \(remaining) more items…")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color.white.opacity(0.03))
    }

    private func categoryHeader(_ category: CleanupCategory) -> some View {
        let isOpen = expanded.contains(category.id)
        return HStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isOpen { expanded.remove(category.id) }
                    else      { expanded.insert(category.id) }
                }
            } label: {
                Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 16)
            }
            .buttonStyle(.plain)

            Button { coord.toggleCategory(category.id) } label: {
                Image(systemName: category.allSelected
                      ? "checkmark.circle.fill"
                      : (category.noneSelected ? "circle" : "minus.circle.fill"))
                    .foregroundStyle(
                        category.allSelected || !category.noneSelected
                            ? .blue : .white.opacity(0.3)
                    )
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)

            Image(systemName: category.icon)
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(category.title)
                    .font(.system(size: 13, weight: .semibold))
                Text("\(category.itemCount) items · \(category.selectedSize.formattedBytes) selected of \(category.totalSize.formattedBytes)")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
            if !category.noneSelected && category.maxSelectedRisk > .safe {
                riskPill(category.maxSelectedRisk)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
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
                Text("\(coord.totalSelectedCount) item\(coord.totalSelectedCount == 1 ? "" : "s") selected")
                    .font(.caption).foregroundStyle(.white.opacity(0.5))
                if coord.totalSelectedCount == 0 {
                    Text("Select items above to clean")
                        .font(.caption).foregroundStyle(.white.opacity(0.35))
                } else {
                    Text(coord.totalSelectedSize.formattedBytes)
                        .font(.title3.bold()).foregroundStyle(.orange)
                }
            }
            // Inline risk summary
            if coord.hasAnyRiskySelected || coord.hasAnyReviewSelected {
                VStack(alignment: .leading, spacing: 2) {
                    if coord.hasAnyRiskySelected {
                        Label("\(coord.riskyItems.count) risky", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.red)
                    }
                    if coord.hasAnyReviewSelected {
                        Label("\(coord.reviewItems.count) review", systemImage: "exclamationmark.circle.fill")
                            .font(.caption).foregroundStyle(.yellow)
                    }
                }
            }
            Spacer()
            Button("Cancel") { coord.cancel() }
                .buttonStyle(.bordered).foregroundStyle(.white)
            Button(coord.hasAnyRiskySelected || coord.hasAnyReviewSelected
                   ? "Continue…" : "Clean \(coord.totalSelectedSize.compactBytes)") {
                coord.confirm()
            }
            .buttonStyle(.borderedProminent).tint(.orange)
            .disabled(coord.totalSelectedSize == 0)
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
    }
}
