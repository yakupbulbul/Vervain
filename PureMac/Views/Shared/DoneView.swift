import SwiftUI

struct DoneView: View {
    let freedBytes: Int64
    let message: String
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: true)

            VStack(spacing: 8) {
                Text(message)
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text("\(freedBytes.formattedBytes) freed")
                    .font(.title3)
                    .foregroundStyle(.green)
            }

            if let onDismiss {
                Button("Done") { onDismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - SizeBadge

struct SizeBadge: View {
    let bytes: Int64
    var color: Color = .orange

    var body: some View {
        Text(bytes.compactBytes)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.9), in: Capsule())
    }
}
