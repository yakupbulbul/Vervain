import SwiftUI
import AppKit

/// Dismissible banner shown when `FullDiskAccessViewModel.shouldShowBanner`
/// is true. Replaces the always-on placeholder from Phase 0 with a probed
/// version that only nudges the user when they actually need to act.
struct FullDiskAccessBanner: View {
    @Environment(FullDiskAccessViewModel.self) private var fda

    var body: some View {
        if fda.shouldShowBanner {
            HStack(spacing: 12) {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(Theme.fdaBannerAccent)
                    .font(.system(size: 18))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Full Disk Access recommended")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("PureMac runs entirely on your Mac. Granting access lets it scan protected folders too.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()

                Button("Grant Access") {
                    fda.openSystemSettings()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundStyle(Theme.fdaBannerAccent)

                Button {
                    fda.dismissBanner()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textMuted)
                }
                .buttonStyle(.plain)
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
