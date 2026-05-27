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
        .onAppear {
            if icon == nil {
                icon = NSWorkspace.shared.icon(forFile: appURL.path)
            }
        }
        .onChange(of: appURL) {
            icon = NSWorkspace.shared.icon(forFile: appURL.path)
        }
    }
}
