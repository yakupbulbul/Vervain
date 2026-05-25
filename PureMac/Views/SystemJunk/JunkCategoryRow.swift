import SwiftUI

struct JunkCategoryRow: View {
    let category: JunkCategory
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Toggle checkbox
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .white.opacity(0.3))
                    .font(.system(size: 18))
                    .animation(.easeInOut(duration: 0.15), value: isSelected)
            }
            .buttonStyle(.plain)

            // Icon
            Image(systemName: category.id.icon)
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 22)

            // Name + file count
            VStack(alignment: .leading, spacing: 2) {
                Text(category.id.rawValue)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                Text("\(category.files.count) \(category.files.count == 1 ? "item" : "items")")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            // Size badge
            SizeBadge(bytes: category.totalSize, color: isSelected ? .orange : .gray)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
    }
}
