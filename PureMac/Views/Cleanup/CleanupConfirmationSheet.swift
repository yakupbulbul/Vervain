import SwiftUI

/// Final confirmation step shown when the user has any risky or review-level
/// items in their cleanup selection. Requires an explicit acknowledgement
/// checkbox before the Confirm & Clean button enables.
struct CleanupConfirmationSheet: View {
    @Environment(CleanupCoordinator.self) private var coord
    @State private var acknowledged = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerBlock

                    if coord.hasAnyRiskySelected {
                        riskySection
                    }
                    if coord.hasAnyReviewSelected {
                        reviewSection
                    }

                    acknowledgeBox
                }
                .padding(20)
            }

            Divider().background(Color.white.opacity(0.08))

            HStack {
                Button("Back to Review") { coord.backToReview() }
                    .buttonStyle(.bordered).foregroundStyle(.white)
                Spacer()
                Button {
                    coord.executeNow()
                } label: {
                    Text("Confirm & Clean \(coord.totalSelectedSize.compactBytes)")
                }
                .buttonStyle(.borderedProminent).tint(.red)
                .disabled(!acknowledged)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
        }
    }

    // MARK: - Sections

    private var headerBlock: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 28))
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 4) {
                Text("Some items need a closer look")
                    .font(.title3.bold())
                Text("PureMac moves files to Trash so nothing is permanently lost, but please confirm the items below before continuing.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private var riskySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Risky", icon: "exclamationmark.triangle.fill", color: .red,
                          count: coord.riskyItems.count)
            VStack(spacing: 0) {
                ForEach(coord.riskyItems.prefix(6)) { item in
                    inlineRow(item)
                }
                if coord.riskyItems.count > 6 {
                    Text("and \(coord.riskyItems.count - 6) more…")
                        .font(.caption).foregroundStyle(.white.opacity(0.4))
                        .padding(.leading, 12).padding(.top, 4)
                }
            }
            .padding(.vertical, 6).padding(.horizontal, 10)
            .background(Color.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Review", icon: "exclamationmark.circle.fill", color: .yellow,
                          count: coord.reviewItems.count)
            VStack(spacing: 0) {
                ForEach(coord.reviewItems.prefix(6)) { item in
                    inlineRow(item)
                }
                if coord.reviewItems.count > 6 {
                    Text("and \(coord.reviewItems.count - 6) more…")
                        .font(.caption).foregroundStyle(.white.opacity(0.4))
                        .padding(.leading, 12).padding(.top, 4)
                }
            }
            .padding(.vertical, 6).padding(.horizontal, 10)
            .background(Color.yellow.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func sectionHeader(_ title: String, icon: String, color: Color, count: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(color)
            Text("\(title) — \(count) item\(count == 1 ? "" : "s")")
                .font(.subheadline.bold())
        }
    }

    private func inlineRow(_ item: CleanupItem) -> some View {
        HStack(spacing: 8) {
            Text(item.name)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
            Text(item.displayPath)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Text(item.size.compactBytes)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.vertical, 3)
    }

    private var acknowledgeBox: some View {
        Button {
            acknowledged.toggle()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: acknowledged ? "checkmark.square.fill" : "square")
                    .foregroundStyle(acknowledged ? .blue : .white.opacity(0.4))
                    .font(.system(size: 16))
                Text("I've reviewed the items above and understand they will be moved to Trash.")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 10).padding(.horizontal, 12)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }
}
