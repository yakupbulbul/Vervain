import SwiftUI

/// Centralised design tokens for PureMac's organic, eco-conscious visual identity.
/// Every colour adapts automatically to macOS light / dark appearance.
enum Theme {

    // MARK: - Backgrounds

    /// Main content background.
    static let background = Color(
        light: Color(red: 0.96, green: 0.94, blue: 0.90),   // warm cream   #F5F0E6
        dark:  Color(red: 0.10, green: 0.09, blue: 0.07)    // warm charcoal #1A1712
    )

    /// Sidebar / navigation rail background.
    static let sidebarBackground = Color(
        light: Color(red: 0.92, green: 0.90, blue: 0.85),   // deeper cream  #EBE6D9
        dark:  Color(red: 0.12, green: 0.11, blue: 0.08)    // warm brown    #1F1C14
    )

    /// Elevated surface — cards, popovers, sheets.
    static let surface = Color(
        light: Color(red: 0.98, green: 0.96, blue: 0.93),   // near-white    #FAF5ED
        dark:  Color(red: 0.14, green: 0.13, blue: 0.10)    // light charcoal #24211A
    )

    /// Subtle overlay tint (selected rows, hover states).
    static let surfaceOverlay = Color(
        light: Color.black.opacity(0.04),
        dark:  Color.white.opacity(0.04)
    )

    // MARK: - Text hierarchy

    /// Primary body text.
    static let textPrimary = Color(
        light: Color(red: 0.15, green: 0.13, blue: 0.10),   // warm near-black
        dark:  Color.white
    )

    /// Secondary descriptions and labels.
    static let textSecondary = Color(
        light: Color(red: 0.15, green: 0.13, blue: 0.10).opacity(0.55),
        dark:  Color.white.opacity(0.55)
    )

    /// Muted captions, hints, placeholders.
    static let textMuted = Color(
        light: Color(red: 0.15, green: 0.13, blue: 0.10).opacity(0.35),
        dark:  Color.white.opacity(0.35)
    )

    /// Even more subtle than muted — breadcrumb separators, empty-state text.
    static let textFaint = Color(
        light: Color(red: 0.15, green: 0.13, blue: 0.10).opacity(0.25),
        dark:  Color.white.opacity(0.25)
    )

    // MARK: - Dividers & borders

    /// Standard thin divider.
    static let divider = Color(
        light: Color.black.opacity(0.10),
        dark:  Color.white.opacity(0.08)
    )

    // MARK: - Module accent colours

    /// Smart Scan — forest green (health, nurture).
    static let smartScanAccent = Color(red: 0.22, green: 0.56, blue: 0.35)

    /// System Junk — warm amber (recycling, reclaiming).
    static let systemJunkAccent = Color(red: 0.78, green: 0.55, blue: 0.18)

    /// App Uninstaller — terracotta (earth, decomposition).
    static let appUninstallerAccent = Color(red: 0.74, green: 0.40, blue: 0.26)

    /// Disk Analyzer — sage (growth, organic data).
    static let diskAnalyzerAccent = Color(red: 0.40, green: 0.58, blue: 0.44)

    // MARK: - Brand

    /// Primary brand colour — forest green.
    static let brandPrimary = smartScanAccent

    /// Secondary brand colour — warm amber.
    static let brandSecondary = systemJunkAccent

    /// Brand gradient applied to the sidebar header icon, onboarding, and idle heroes.
    static func brandGradient(
        startPoint: UnitPoint = .topLeading,
        endPoint: UnitPoint = .bottomTrailing
    ) -> LinearGradient {
        LinearGradient(
            colors: [brandPrimary, brandSecondary],
            startPoint: startPoint,
            endPoint: endPoint
        )
    }

    // MARK: - Status colours (semantic)

    /// Safe / good / success.
    static let statusSafe = Color.green

    /// Review / caution / warning — uses the warm amber accent.
    static let statusReview = systemJunkAccent

    /// Risky / critical / danger — uses the terracotta accent.
    static let statusRisky = appUninstallerAccent

    /// Informational — uses the sage accent.
    static let statusInfo = diskAnalyzerAccent

    // MARK: - FDA banner

    /// FDA banner background tint.
    static let fdaBannerBackground = Color(
        light: systemJunkAccent.opacity(0.12),
        dark:  systemJunkAccent.opacity(0.12)
    )

    /// FDA banner accent (icons, button text).
    static let fdaBannerAccent = systemJunkAccent

    // MARK: - Disk category chart colours (warm palette)

    static let chartApplications = Color(red: 0.35, green: 0.55, blue: 0.62) // sage blue
    static let chartDocuments    = Color(red: 0.38, green: 0.58, blue: 0.35) // moss green
    static let chartMedia        = systemJunkAccent                           // warm amber
    static let chartDeveloper    = Color(red: 0.55, green: 0.35, blue: 0.55) // plum
    static let chartLibrary      = Color(red: 0.50, green: 0.55, blue: 0.32) // olive
    static let chartOther        = Color(red: 0.45, green: 0.43, blue: 0.40) // stone

    // MARK: - Health score tier gradients

    static let healthGood     = [Color.green, Color.mint]
    static let healthWarning  = [systemJunkAccent, Color.orange]
    static let healthCritical = [appUninstallerAccent, Color.red]
}
