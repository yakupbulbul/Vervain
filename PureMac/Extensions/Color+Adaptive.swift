import SwiftUI
import AppKit

extension Color {
    /// Creates a color that automatically adapts to the current macOS appearance.
    /// - Parameters:
    ///   - light: Color used when the system appearance is light (Aqua).
    ///   - dark: Color used when the system appearance is dark (Dark Aqua).
    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? NSColor(dark) : NSColor(light)
        })
    }
}
