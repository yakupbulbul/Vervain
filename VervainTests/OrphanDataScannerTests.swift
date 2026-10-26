import XCTest
@testable import Vervain

final class OrphanDataScannerTests: XCTestCase {

    private var home: URL!

    override func setUpWithError() throws {
        home = FileManager.default.temporaryDirectory
            .appendingPathComponent("vervain-orphan-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: home.appendingPathComponent("Library/Preferences"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: home.appendingPathComponent("Library/Application Support"), withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: home)
    }

    @discardableResult
    private func write(_ relative: String, daysOld: Int = 90) throws -> URL {
        let url = home.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(count: 4_096).write(to: url)
        let date = Date(timeIntervalSinceNow: -Double(daysOld) * 86_400)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
        return url
    }

    func testBundleIDExtraction() {
        XCTAssertEqual(OrphanDataScanner.bundleID(fromEntryName: "com.foo.bar.plist"), "com.foo.bar")
        XCTAssertEqual(OrphanDataScanner.bundleID(fromEntryName: "com.foo.bar.savedState"), "com.foo.bar")
        XCTAssertEqual(OrphanDataScanner.bundleID(fromEntryName: "group.com.foo.bar"), "com.foo.bar")
        XCTAssertEqual(OrphanDataScanner.bundleID(fromEntryName: "ABCDE12345.com.foo.bar"), "com.foo.bar")
        XCTAssertNil(OrphanDataScanner.bundleID(fromEntryName: "Spotify"))
        XCTAssertNil(OrphanDataScanner.bundleID(fromEntryName: "com.foo"))
        XCTAssertNil(OrphanDataScanner.bundleID(fromEntryName: "notes.backup.txt"))
    }

    func testInstalledMatchIncludesHelpers() {
        let installed = ["com.google.chrome"]
        XCTAssertTrue(OrphanDataScanner.isInstalled("com.google.chrome", installed: installed))
        XCTAssertTrue(OrphanDataScanner.isInstalled("com.google.chrome.helper", installed: installed))
        XCTAssertFalse(OrphanDataScanner.isInstalled("com.google.chromecast", installed: installed))
    }

    func testFlagsOnlyEntriesWhoseAppIsGone() async throws {
        try write("Library/Preferences/com.removed.app.plist")
        try write("Library/Preferences/com.installed.app.plist")
        try write("Library/Preferences/com.apple.finder.plist")
        try write("Library/Application Support/com.removed.app/data.db")

        let (cats, _) = try await OrphanDataScanner().scan(home: home, installedBundleIDs: ["com.installed.app"])
        let names = Set(cats.flatMap(\.items).map(\.name))
        XCTAssertEqual(names, ["com.removed.app.plist", "com.removed.app"])
    }

    func testNothingIsSelectedByDefaultAndRecentEntriesAreSkipped() async throws {
        try write("Library/Preferences/com.removed.old.plist", daysOld: 90)
        try write("Library/Preferences/com.removed.recent.plist", daysOld: 2)

        let (cats, _) = try await OrphanDataScanner().scan(home: home, installedBundleIDs: [])
        let items = cats.flatMap(\.items)
        XCTAssertEqual(items.map(\.name), ["com.removed.old.plist"])
        XCTAssertTrue(items.allSatisfy { !$0.isSelected })
    }
}
