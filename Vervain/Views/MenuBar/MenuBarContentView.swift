import SwiftUI

/// Content of the optional menu bar item: disk usage plus a quick junk scan.
/// Works entirely offline and reuses the app's System Junk scanner.
struct MenuBarContentView: View {
    @Environment(SystemJunkViewModel.self) private var junk
    @State private var usage = DiskUsage.current()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let usage {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Startup Disk").font(.headline)
                    ProgressView(value: usage.usedFraction)
                        .tint(usage.usedFraction > 0.9 ? Theme.statusRisky : Theme.smartScanAccent)
                    Text("\(usage.used.formattedBytes) of \(usage.total.formattedBytes) used")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("\(usage.available.formattedBytes) available")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Divider()

            if junk.isScanning {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Scanning your Mac…").font(.caption)
                }
            } else if junk.state == .results {
                let found = junk.categories.reduce(Int64(0)) { $0 + $1.totalSize }
                Text("\(found.formattedBytes) of junk found").font(.caption)
            }

            Button("Quick Scan") { junk.scan() }
                .disabled(junk.isScanning)
            Button("Open Vervain") { Self.showMainWindow() }
            Divider()
            Button("Quit Vervain") { NSApplication.shared.terminate(nil) }
        }
        .padding(14)
        .frame(width: 270)
        .onAppear { usage = DiskUsage.current() }
    }

    private static func showMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window = NSApplication.shared.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            NSWorkspace.shared.open(Bundle.main.bundleURL)
        }
    }
}
