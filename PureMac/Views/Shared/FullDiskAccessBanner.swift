import SwiftUI
import AppKit

/// A dismissible banner that prompts the user to grant Full Disk Access
/// when PureMac can't read protected directories.
struct FullDiskAccessBanner: View {
    @State private var isDismissed = false

    var body: some View {
        if !isDismissed {
            HStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(.yellow)
                    .font(.system(size: 18))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Full Disk Access recommended")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Some directories may be skipped without it.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                Button("Grant Access") {
                    openFullDiskAccessPrefs()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundStyle(.yellow)

                Button {
                    withAnimation(.easeOut(duration: 0.2)) { isDismissed = true }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.yellow.opacity(0.12))
            .overlay(alignment: .bottom) {
                Divider().background(Color.yellow.opacity(0.2))
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func openFullDiskAccessPrefs() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }
}
