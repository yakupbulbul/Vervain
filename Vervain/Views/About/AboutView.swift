import SwiftUI
import AppKit

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.textMuted)
                }
                .buttonStyle(.plain)
                .padding(12)
            }

            appIdentity
            tagline
            Divider().background(Theme.divider).padding(.horizontal, 24)
            links
            Divider().background(Theme.divider).padding(.horizontal, 24)
            footer
        }
        .frame(width: 320)
        .background(Theme.background)
        .foregroundStyle(Theme.textPrimary)
    }

    // MARK: - Identity

    private var appIdentity: some View {
        VStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)

            Text("Vervain")
                .font(.system(size: 20, weight: .bold))

            Text("Mac Care")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textMuted)

            Text("Version \(version) (\(build))")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.top, 0)
        .padding(.bottom, 16)
    }

    // MARK: - Tagline

    private var tagline: some View {
        Text("Private by design. Open source.\nNo telemetry.")
            .font(.system(size: 12))
            .foregroundStyle(Theme.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.vertical, 14)
    }

    // MARK: - Links

    private var links: some View {
        VStack(spacing: 1) {
            linkRow(icon: "globe", label: "Website", url: "https://vervain.app")
            linkRow(icon: "chevron.left.forwardslash.chevron.right", label: "Source Code", url: "https://github.com/yakupbulbul/Vervain")
            linkRow(icon: "cup.and.saucer.fill", label: "Buy Me a Coffee", url: "https://buymeacoffee.com/yakupbulbul")
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private func linkRow(icon: String, label: String, url: String) -> some View {
        Button {
            if let u = URL(string: url) { NSWorkspace.shared.open(u) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.brandPrimary)
                    .frame(width: 20)
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.textFaint)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 4) {
            Text("Made by Yakup Bülbül")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            Text("© 2026 Yakup Bülbül. All rights reserved.")
                .font(.system(size: 10))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(.vertical, 16)
    }
}
