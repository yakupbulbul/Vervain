import XCTest
@testable import Vervain

final class DirectoryStatsTests: XCTestCase {

    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("vervain-stats-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testSumsFilesAndFindsNewestModification() throws {
        let sub = root.appendingPathComponent("a/b")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        let old = root.appendingPathComponent("old.bin")
        let new = sub.appendingPathComponent("new.bin")
        try Data(count: 10_000).write(to: old)
        try Data(count: 10_000).write(to: new)
        let oldDate = Date(timeIntervalSinceNow: -90 * 86_400)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: old.path)

        let stats = directoryStats(at: root)
        XCTAssertGreaterThanOrEqual(stats.size, 20_000)
        XCTAssertGreaterThan(stats.newestModification, Date(timeIntervalSinceNow: -60))
        XCTAssertEqual(stats.inaccessibleCount, 0)
    }

    func testEmptyDirectoryHasZeroSize() {
        XCTAssertEqual(directoryStats(at: root).size, 0)
    }
}
