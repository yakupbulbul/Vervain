import SwiftUI
import AppKit

struct AppIconView: View {
    let appURL: URL

    @State private var icon: NSImage?

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .task(id: appURL) {
            // NSWorkspace must be accessed on MainActor
            icon = await MainActor.run {
                NSWorkspace.shared.icon(forFile: appURL.path)
            }
        }
    }
}
