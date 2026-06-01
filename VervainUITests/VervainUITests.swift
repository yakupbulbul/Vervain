import XCTest

/// UI tests for Vervain. These drive the real app through the XCTest
/// automation framework (which has proper accessibility injection rights).
final class VervainUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()

        // Dismiss any system permission dialogs (Apple Music, Contacts, etc.)
        // that the scan might trigger. Always deny — we're just testing UI flow.
        addUIInterruptionMonitor(withDescription: "System permission dialog") { alert in
            // Prefer "Don't Allow" / "Deny" / "Not Now"; fall back to first button
            let denyLabels = ["Don't Allow", "Deny", "Not Now", "OK"]
            for label in denyLabels {
                let btn = alert.buttons[label]
                if btn.exists { btn.click(); return true }
            }
            // Last resort: dismiss via the first button
            alert.buttons.firstMatch.click()
            return true
        }

        // Dismiss onboarding if it appears (first-launch sheet)
        dismissOnboardingIfPresent()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    /// Dismiss the "Welcome to Vervain" onboarding sheet if it's visible.
    private func dismissOnboardingIfPresent() {
        let getStarted = app.buttons["Get Started"]
        if getStarted.waitForExistence(timeout: 3) {
            getStarted.click()
            // Wait for sheet to dismiss
            _ = app.buttons["Scan Now"].waitForExistence(timeout: 3)
        }
    }

    private func screenshot(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    // MARK: - 01: Launch

    func test01_AppLaunchesAndShowsSidebar() {
        // The app should show the Smart Scan module by default.
        // In a NavigationSplitView, sidebar labels appear in the list.
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5),
                      "No window visible after launch")

        screenshot("01_launch")

        // Sidebar entries — check they exist somewhere in the view hierarchy
        let sidebarTexts = ["Smart Scan", "System Junk", "App Uninstaller", "Disk Analyzer"]
        for label in sidebarTexts {
            XCTAssertTrue(
                app.staticTexts[label].exists || app.buttons[label].exists,
                "'\(label)' not found in sidebar"
            )
        }

        // Idle / ready state shown in content pane
        XCTAssertTrue(
            app.staticTexts["Ready to Scan"].exists ||
            app.staticTexts["Health Score"].exists,
            "Smart Scan content pane not showing expected content"
        )
    }

    // MARK: - 02: Smart Scan

    func test02_SmartScanFlow() {
        app.activate()
        // Find and click the scan button (toolbar or content pane)
        let scanNow = app.buttons["Scan Now"]
        let startScan = app.buttons["Start Smart Scan"]

        if scanNow.waitForExistence(timeout: 3) {
            scanNow.click()
        } else if startScan.waitForExistence(timeout: 3) {
            startScan.click()
        } else {
            XCTFail("Could not find any scan button in SmartScan view")
            return
        }

        screenshot("02a_smartscan_scanning")

        // Wait for results (up to 30s — real disk scan)
        let healthScore = app.staticTexts["Health Score"]
        XCTAssertTrue(healthScore.waitForExistence(timeout: 30),
                      "Smart Scan results never appeared within 30s")

        screenshot("02b_smartscan_results")

        // Review Cleanup CTA — appears when junk was found
        let reviewBtn = app.buttons["Review Cleanup"]
        if reviewBtn.waitForExistence(timeout: 3) {
            reviewBtn.click()

            // Sheet should open with the title
            let sheetTitle = app.staticTexts["Review Smart Scan Findings"]
            XCTAssertTrue(sheetTitle.waitForExistence(timeout: 5),
                          "Review sheet did not open")

            screenshot("02c_review_sheet")

            // Verify first category is auto-expanded (items visible)
            // There should be CleanupItemRow elements visible without needing to expand
            XCTAssertTrue(
                app.staticTexts.count > 6,
                "Review sheet seems empty — first category should be auto-expanded"
            )

            // Close without cleaning
            let cancelBtn = app.buttons["Cancel"].firstMatch
            XCTAssertTrue(cancelBtn.exists, "Cancel button missing in review sheet")
            cancelBtn.click()

            // Sheet should dismiss
            XCTAssertFalse(sheetTitle.waitForExistence(timeout: 3))

            screenshot("02d_after_cancel")
        }
    }

    // MARK: - 03: System Junk

    func test03_SystemJunkModule() {
        // Navigate to System Junk
        app.activate()
        let sidebarItem = app.staticTexts["System Junk"].firstMatch
        XCTAssertTrue(sidebarItem.waitForExistence(timeout: 5))
        sidebarItem.click()

        // Idle state
        XCTAssertTrue(
            app.staticTexts["Clean System Junk"].waitForExistence(timeout: 5),
            "System Junk idle state not shown"
        )

        screenshot("03a_junk_idle")

        // Start scan
        let scanBtn = app.buttons["Scan for Junk"]
        XCTAssertTrue(scanBtn.waitForExistence(timeout: 5))
        scanBtn.click()

        screenshot("03b_junk_scanning")

        // Wait for results (up to 150s). The first run may show system permission dialogs
        // (Apple Music, Contacts) that take time to process. After the first run those
        // dialogs don't appear again. The JunkScanner intentionally skips TCC-sensitive
        // cache directories (Music, AMPLibraryAgent, etc.) to prevent those dialogs.
        let scanningText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Scanning'")
        ).firstMatch
        _ = scanningText.waitForExistence(timeout: 3)  // may appear briefly

        // Activate the app periodically so the UIInterruptionMonitor has a chance to
        // fire and dismiss any system permission dialogs that appear mid-scan.
        let reScanBtn = app.buttons["Re-Scan"]
        let cleanMsg  = app.staticTexts["Your Mac is Clean!"]
        var found = false
        for i in 0..<30 {   // 30 × 5s = 150s max
            if reScanBtn.waitForExistence(timeout: 5) || cleanMsg.exists { found = true; break }
            // Re-activate app every 10s so interrupt monitor can fire
            if i % 2 == 1 { app.activate() }
        }
        XCTAssertTrue(found, "System Junk scan didn't complete in 150s")

        screenshot("03c_junk_results")

        // If items found, try opening review sheet
        let reviewBtn = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Review & Clean'")
        ).firstMatch
        if reviewBtn.waitForExistence(timeout: 3) && reviewBtn.isEnabled {
            reviewBtn.click()

            let sheetTitle = app.staticTexts["Review System Junk"]
            XCTAssertTrue(sheetTitle.waitForExistence(timeout: 5),
                          "System Junk review sheet didn't open")

            screenshot("03d_junk_review")

            // Close
            app.buttons["Cancel"].firstMatch.click()
            _ = app.staticTexts["Clean System Junk"].waitForExistence(timeout: 3)

            screenshot("03e_after_junk_cancel")
        }
    }

    // MARK: - 04: App Uninstaller

    func test04_AppUninstallerModule() {
        app.activate()
        let sidebarItem = app.staticTexts["App Uninstaller"].firstMatch
        XCTAssertTrue(sidebarItem.waitForExistence(timeout: 5))
        sidebarItem.click()

        XCTAssertTrue(
            app.staticTexts["Remove Apps Completely"].waitForExistence(timeout: 8),
            "App Uninstaller idle state not shown"
        )

        screenshot("04a_appuninstaller_idle")

        app.buttons["Scan Applications"].click()

        screenshot("04b_appuninstaller_scanning")

        // Wait up to 15s for apps to appear
        let appEntry = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '.' AND NOT label CONTAINS 'Applications'")
        ).firstMatch
        _ = appEntry.waitForExistence(timeout: 15)

        screenshot("04c_appuninstaller_results")

        // Should have apps listed — check for the "Leftovers" button or app name texts
        // (bundle IDs may be truncated in the accessibility tree)
        let leftoversBtn = app.buttons.matching(
            NSPredicate(format: "label == 'Leftovers'")
        ).firstMatch
        let hasApps = leftoversBtn.waitForExistence(timeout: 5) ||
                      app.staticTexts.count > 5
        XCTAssertTrue(hasApps, "App Uninstaller list appears empty — no Leftovers buttons or app entries")
    }

    // MARK: - 05: Disk Analyzer

    func test05_DiskAnalyzerModule() {
        let sidebarItem = app.staticTexts["Disk Analyzer"].firstMatch
        XCTAssertTrue(sidebarItem.waitForExistence(timeout: 3))
        sidebarItem.click()

        screenshot("05a_diskanalyzer_idle")

        // Start analysis — look for any button containing "Analyze"
        let analyzeBtn = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Analyze' OR label CONTAINS 'analyze'")
        ).firstMatch
        if analyzeBtn.waitForExistence(timeout: 3) {
            analyzeBtn.click()

            screenshot("05b_diskanalyzer_scanning")

            // Wait for results — size values should appear
            let sizeLabel = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS 'GB' OR label CONTAINS 'MB'")
            ).firstMatch
            _ = sizeLabel.waitForExistence(timeout: 30)

            screenshot("05c_diskanalyzer_results")
        } else {
            // Already in results state from previous run
            screenshot("05_diskanalyzer_state")
        }
    }

    // MARK: - 06: Sidebar navigation round-trip

    func test06_SidebarNavigation() {
        let navItems: [String] = [
            "System Junk", "App Uninstaller", "Disk Analyzer", "Smart Scan"
        ]
        for label in navItems {
            let item = app.staticTexts[label].firstMatch
            if item.waitForExistence(timeout: 2) { item.click() }
            // Let each view settle
            Thread.sleep(forTimeInterval: 0.5)
            screenshot("06_nav_\(label.replacingOccurrences(of: " ", with: "_"))")
        }
    }
}
