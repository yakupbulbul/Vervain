import XCTest
@testable import Vervain

final class DuplicateScannerTests: XCTestCase {

    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("vervain-dups-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    private func write(_ name: String, _ data: Data, daysOld: Int = 0) throws -> URL {
        let url = root.appendingPathComponent(name)
        try data.write(to: url)
        let date = Date(timeIntervalSinceNow: -Double(daysOld) * 86_400)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
        return url
    }

    func testKeepsOldestAndListsOnlyCopies() async throws {
        let payload = Data(repeating: 7, count: 2_000)
        try write("original.bin", payload, daysOld: 100)
        try write("copy1.bin", payload, daysOld: 10)
        try write("copy2.bin", payload, daysOld: 1)

        let (cats, _) = try await DuplicateScanner().scan(roots: [root], minSize: 1_000)
        XCTAssertEqual(cats.count, 1)
        let names = Set(cats[0].items.map(\.name))
        XCTAssertEqual(names, ["copy1.bin", "copy2.bin"])
        XCTAssertFalse(names.contains("original.bin"))
    }

    func testSameSizeDifferentContentIsNotDuplicate() async throws {
        try write("a.bin", Data(repeating: 1, count: 2_000))
        try write("b.bin", Data(repeating: 2, count: 2_000))
        let (cats, _) = try await DuplicateScanner().scan(roots: [root], minSize: 1_000)
        XCTAssertTrue(cats.isEmpty)
    }

    func testDifferenceAfterFirst64KBIsDetectedByFullHash() async throws {
        var a = Data(repeating: 5, count: 200_000)
        var b = a
        a[199_999] = 1
        b[199_999] = 2
        try write("a.bin", a)
        try write("b.bin", b)
        let (cats, _) = try await DuplicateScanner().scan(roots: [root], minSize: 1_000)
        XCTAssertTrue(cats.isEmpty)
    }

    func testFilesBelowMinimumSizeAreIgnored() async throws {
        let payload = Data(repeating: 9, count: 500)
        try write("x.bin", payload)
        try write("y.bin", payload)
        let (cats, _) = try await DuplicateScanner().scan(roots: [root], minSize: 1_000)
        XCTAssertTrue(cats.isEmpty)
    }

    func testDuplicateItemsAreNotSelectedByDefault() async throws {
        let payload = Data(repeating: 3, count: 2_000)
        try write("a.bin", payload, daysOld: 5)
        try write("b.bin", payload)
        let (cats, _) = try await DuplicateScanner().scan(roots: [root], minSize: 1_000)
        XCTAssertTrue(cats.flatMap(\.items).allSatisfy { !$0.isSelected })
    }
}

final class DuplicateKeepRuleTests: XCTestCase {

    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("vervain-keep-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("deep/er"), withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func write(_ relative: String, daysOld: Int) throws {
        let url = root.appendingPathComponent(relative)
        try Data(repeating: 4, count: 2_000).write(to: url)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -Double(daysOld) * 86_400)], ofItemAtPath: url.path)
    }

    func testNewestRuleKeepsTheNewestCopy() async throws {
        try write("old.bin", daysOld: 100)
        try write("new.bin", daysOld: 1)
        let (cats, _) = try await DuplicateScanner().scan(roots: [root], minSize: 1_000, keepRule: .newest)
        XCTAssertEqual(cats.first?.items.map(\.name), ["old.bin"])
    }

    func testShallowestRuleKeepsTheCopyClosestToTheRoot() async throws {
        try write("top.bin", daysOld: 1)
        try write("deep/er/nested.bin", daysOld: 500)
        let (cats, _) = try await DuplicateScanner().scan(roots: [root], minSize: 1_000, keepRule: .shortestPath)
        XCTAssertEqual(cats.first?.items.map(\.name), ["nested.bin"])
    }

    func testHardLinksAreNotReportedAsDuplicates() async throws {
        try write("original.bin", daysOld: 10)
        try FileManager.default.linkItem(at: root.appendingPathComponent("original.bin"),
                                         to: root.appendingPathComponent("hardlink.bin"))
        let (cats, _) = try await DuplicateScanner().scan(roots: [root], minSize: 1_000)
        XCTAssertTrue(cats.isEmpty, "a hard link frees no space when trashed")
    }

    func testRuleOrdering() {
        let early = Date(timeIntervalSince1970: 1_000), late = Date(timeIntervalSince1970: 2_000)
        XCTAssertTrue(DuplicateKeepRule.oldest.isBetterToKeep("/a", early, than: "/b", late))
        XCTAssertTrue(DuplicateKeepRule.newest.isBetterToKeep("/a", late, than: "/b", early))
        XCTAssertTrue(DuplicateKeepRule.shortestPath.isBetterToKeep("/a", late, than: "/a/b/c", early))
    }
}
