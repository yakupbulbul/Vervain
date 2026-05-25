import SwiftUI

/// Row in the System Junk results list. Shows category info, selection state,
/// and a per-row risk pill. Will be superseded by the universal CleanupItemRow
/// in Phase 3 once the review flow lands.
struct JunkCategoryRow: View {
    let category: CleanupCategory
    let onToggle: () -> Void

    private var isSelected: Bool { category.allSelected }
    private var isPartial: Bool { !category.noneSelected && !category.allSelected }

    private var riskPill: CleanupRiskLevel {
        category.items.map(\.riskLevel).max() ?? .safe
    }

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onToggle) {
                Image(systemName: isSelected
                      ? "checkmark.circle.fill"
                      : (isPartial ? "minus.circle.fill" : "circle"))
                    .foregroundStyle(isSelected || isPartial ? .blue : .white.opacity(0.3))
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)

            Image(systemName: category.icon)
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(category.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    riskBadge(riskPill)
                }
                if let sub = category.subtitle {
                    Text(sub)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                }
                Text("\(category.itemCount) \(category.itemCount == 1 ? "item" : "items") · \(category.selectedCount) selected")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.35))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                SizeBadge(bytes: category.totalSize, color: .orange)
                if category.selectedSize > 0 && category.selectedSize != category.totalSize {
                    Text(category.selectedSize.compactBytes + " sel.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
    }

    private func riskBadge(_ risk: CleanupRiskLevel) -> some View {
        HStack(spacing: 3) {
            Image(systemName: risk.icon).font(.system(size: 9, weight: .bold))
            Text(risk.label).font(.system(size: 10, weight: .semibold))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .foregroundStyle(risk.color)
        .background(risk.color.opacity(0.15), in: Capsule())
    }
}
