import SwiftUI

/// Shown while a cleanup batch is executing. Updates from CleanupProgress
/// stream — kept simple to stay calming under load.
struct CleanupProgressView: View {
    @Environment(CleanupCoordinator.self) private var coord

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "trash.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
                .symbolEffect(.pulse)
            VStack(spacing: 6) {
                Text("Moving items to Trash…")
                    .font(.title3.bold())
                if let p = coord.progress {
                    Text("\(p.currentIndex) of \(p.totalCount)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                    if let current = p.currentItem {
                        Text(current.displayPath)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.horizontal, 40)
                    }
                }
            }
            ProgressView(value: coord.progress?.fraction ?? 0)
                .progressViewStyle(.linear).tint(.orange)
                .frame(width: 420)
            if let p = coord.progress {
                Text("\(p.bytesFreed.formattedBytes) freed of \(p.totalBytes.formattedBytes)")
                    .font(.caption).foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
