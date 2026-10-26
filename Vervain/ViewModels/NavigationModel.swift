import SwiftUI

/// Which module is showing, shared between the window and the menu bar
/// commands so ⌘1…⌘9 and ⌘R work from anywhere in the app.
@Observable
@MainActor
final class NavigationModel {
    var selected: AppFeature? = .smartScan
    /// Bumped by ⌘R; the content view reacts by re-running the current module's scan.
    private(set) var rescanTick = 0

    func requestRescan() { rescanTick += 1 }

    /// Feature for the ⌘-digit shortcut (1-based), if there is one.
    static func feature(forShortcutNumber number: Int) -> AppFeature? {
        let all = AppFeature.allCases
        guard number >= 1, number <= min(9, all.count) else { return nil }
        return all[number - 1]
    }
}
