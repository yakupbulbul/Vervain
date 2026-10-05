import XCTest
@testable import Vervain

final class AppScannerTests: XCTestCase {

    private func match(_ file: String, bundleID: String = "com.acme.notes", appName: String = "Notes Pro",
                       parent: String = "Application Support") -> CleanupConfidenceLevel? {
        let lower = file.lowercased()
        let stem = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent.lowercased()
        let vendor = bundleID.split(separator: ".").prefix(2).joined(separator: ".").lowercased()
        return AppScanner.matchConfidence(nameLower: lower, nameStem: stem, parent: parent,
                                          bundleIDLow: bundleID.lowercased(), appNameLow: appName.lowercased(),
                                          vendorPrefix: vendor)
    }

    func testExactBundleIDIsHigh() {
        XCTAssertEqual(match("com.acme.notes"), .high)
        XCTAssertEqual(match("com.acme.notes.plist"), .high)
    }

    func testBundleIDPrefixIsMedium() {
        XCTAssertEqual(match("com.acme.notes.helper.plist"), .medium)
    }

    func testGroupContainerSuffixIsMedium() {
        XCTAssertEqual(match("group.com.acme.notes"), .medium)
        XCTAssertEqual(match("ABCDE12345.com.acme.notes"), .medium)
    }

    func testAppNameMustBeWholeWords() {
        XCTAssertEqual(match("Notes Pro Backup", appName: "Notes Pro"), .low)
        XCTAssertNil(match("MailChimp Data", bundleID: "com.rocket.mail", appName: "Mail"))
        XCTAssertNil(match("Hotmail Archive", bundleID: "com.other.thing", appName: "Mail Pro"))
    }

    func testUnrelatedFileDoesNotMatch() {
        XCTAssertNil(match("com.other.app"))
    }

    func testContainsWholeWords() {
        XCTAssertTrue(AppScanner.containsWholeWords("my-notes pro data", "notes pro"))
        XCTAssertFalse(AppScanner.containsWholeWords("notesprodata", "notes pro"))
        XCTAssertFalse(AppScanner.containsWholeWords("anything", ""))
    }

    func testAppleAppsAreProtectedExceptTheRemovableOnes() {
        XCTAssertTrue(AppScanner.isProtectedAppleApp(bundleID: "com.apple.Safari"))
        XCTAssertTrue(AppScanner.isProtectedAppleApp(bundleID: "com.apple.mail"))
        XCTAssertFalse(AppScanner.isProtectedAppleApp(bundleID: "com.apple.dt.Xcode"))
        XCTAssertFalse(AppScanner.isProtectedAppleApp(bundleID: "com.apple.iWork.Pages"))
        XCTAssertFalse(AppScanner.isProtectedAppleApp(bundleID: "com.acme.notes"))
    }
}
