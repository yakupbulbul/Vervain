import SwiftUI

/// Dismissible banner shown when the automatic update check found a newer
/// version. It links to the release page; Vervain never installs anything itself.
struct UpdateBanner: View {
    @Environment(UpdateNoticeViewModel.self) private var updates
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let notice = updates.notice {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(Theme.fdaBannerAccent)
                    .font(.system(size: 18))

                Text("Version \(notice.version) is available")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                Button("Download") { openURL(notice.url) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundStyle(Theme.fdaBannerAccent)

                Button {
                    updates.dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.fdaBannerBackground)
            .overlay(alignment: .bottom) {
                Divider().background(Theme.fdaBannerAccent.opacity(0.2))
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
