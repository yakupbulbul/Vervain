import XCTest
@testable import Vervain

final class CleanupServiceSafetyTests: XCTestCase {

    private let home = URL(fileURLWithPath: "/Users/tester")

    private func safe(_ path: String) -> Bool {
        CleanupService.isSafeToTrash(URL(fileURLWithPath: path), home: home)
    }

    func testRejectsSystemRoots() {
        for path in ["/", "/System", "/System/Library/Foo", "/usr/bin/ls", "/Library", "/Applications", "/Users"] {
            XCTAssertFalse(safe(path), path)
        }
    }

    func testRejectsHomeAndUserFolders() {
        for name in ["", "/Library", "/Documents", "/Desktop", "/Downloads", "/.Trash"] {
            XCTAssertFalse(safe("/Users/tester" + name), name)
        }
    }

    func testRejectsTraversalIntoProtectedPath() {
        XCTAssertFalse(safe("/Users/tester/Library/Caches/../../Documents"))
    }

    func testAllowsRegularTargets() {
        XCTAssertTrue(safe("/Users/tester/Library/Caches/com.example.app"))
        XCTAssertTrue(safe("/Users/tester/Downloads/old.dmg"))
        XCTAssertTrue(safe("/Applications/Example.app"))
    }

    func testRejectsNonFileURL() {
        XCTAssertFalse(CleanupService.isSafeToTrash(URL(string: "https://example.com/a")!, home: home))
    }
}

final class CleanupServiceChangeDetectionTests: XCTestCase {

    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("vervain-change-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func item(for url: URL, scannedAt date: Date?) -> CleanupItem {
        CleanupItem(url: url, size: 1, category: "T", reason: .recentCache,
                    riskLevel: .safe, confidenceLevel: .high,
                    lastModifiedDate: date, sourceModule: .systemJunk)
    }

    func testUnchangedFileIsNotFlagged() throws {
        let url = dir.appendingPathComponent("a.txt")
        try Data("x".utf8).write(to: url)
        let modified = try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        XCTAssertFalse(CleanupService.hasChangedSinceScan(item(for: url, scannedAt: modified)))
    }

    func testFileModifiedAfterScanIsFlagged() throws {
        let url = dir.appendingPathComponent("a.txt")
        try Data("x".utf8).write(to: url)
        let scanned = Date(timeIntervalSinceNow: -3_600)
        XCTAssertTrue(CleanupService.hasChangedSinceScan(item(for: url, scannedAt: scanned)))
    }

    func testItemWithoutRecordedDateIsNotFlagged() throws {
        let url = dir.appendingPathComponent("a.txt")
        try Data("x".utf8).write(to: url)
        XCTAssertFalse(CleanupService.hasChangedSinceScan(item(for: url, scannedAt: nil)))
    }

    func testSymlinkedParentIsResolvedBeforeSafetyCheck() throws {
        let real = dir.appendingPathComponent("real")
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        let link = dir.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
        let resolved = CleanupService.resolvingParentSymlinks(link.appendingPathComponent("file.txt"))
        XCTAssertEqual(resolved.lastPathComponent, "file.txt")
        XCTAssertEqual(resolved.deletingLastPathComponent().path,
                       real.resolvingSymlinksInPath().path)
    }
}
