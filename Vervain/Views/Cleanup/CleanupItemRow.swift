import SwiftUI

/// Shared row used by both the review screen and the per-category lists.
struct CleanupItemRow: View {
    let item: CleanupItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Selection checkbox
            Button(action: onToggle) {
                Image(systemName: item.isSelected
                      ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isSelected ? Theme.smartScanAccent : Theme.textMuted)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isSelected
                                ? String(localized: "Deselect \(item.name)")
                                : String(localized: "Select \(item.name)"))
            .accessibilityIdentifier("cleanup-item-checkbox")

            // Confidence dot
            Circle()
                .fill(item.confidenceLevel.color)
                .frame(width: 6, height: 6)
                .help(item.confidenceLevel.description)

            // Name + path
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(item.displayPath)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Theme.textMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text("·")
                        .foregroundStyle(Theme.textMuted)
                    Text(item.reason.displayText)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                .help(item.url.path)
            }

            Spacer()

            // Risk chip
            riskChip(item.riskLevel)

            // Size
            Text(item.size.compactBytes)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 64, alignment: .trailing)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
        .itemContextMenu(url: item.url)
    }

    @ViewBuilder
    private func riskChip(_ risk: CleanupRiskLevel) -> some View {
        HStack(spacing: 3) {
            Image(systemName: risk.icon).font(.system(size: 8, weight: .bold))
            Text(risk.label).font(.system(size: 9, weight: .semibold))
        }
        .padding(.horizontal, 5).padding(.vertical, 2)
        .foregroundStyle(risk.color)
        .background(risk.color.opacity(0.15), in: Capsule())
    }
}
