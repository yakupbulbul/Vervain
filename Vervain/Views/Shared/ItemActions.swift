import SwiftUI
import QuickLookUI

/// Shows the system Quick Look panel for a file.
@MainActor
final class QuickLookCoordinator: NSObject, @preconcurrency QLPreviewPanelDataSource, @preconcurrency QLPreviewPanelDelegate {
    static let shared = QuickLookCoordinator()
    private var url: URL?

    func show(_ url: URL) {
        self.url = url
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.delegate = self
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        url == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        url as NSURL?
    }
}

/// Right-click actions shared by every list that shows a file or folder.
struct ItemContextMenu: ViewModifier {
    let url: URL
    let allowExclude: Bool
    /// When set, the menu offers "Move to Trash…" which should open the review flow.
    let onTrash: (() -> Void)?

    func body(content: Content) -> some View {
        content.contextMenu {
            Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            Button("Quick Look") { QuickLookCoordinator.shared.show(url) }
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.path, forType: .string)
            }
            if let onTrash {
                Divider()
                Button("Move to Trash…", action: onTrash)
            }
            if allowExclude {
                Divider()
                Button("Never Offer This for Cleanup") { ExclusionList.add(url.path) }
            }
        }
    }
}

extension View {
    func itemContextMenu(url: URL, allowExclude: Bool = true, onTrash: (() -> Void)? = nil) -> some View {
        modifier(ItemContextMenu(url: url, allowExclude: allowExclude, onTrash: onTrash))
    }
}
