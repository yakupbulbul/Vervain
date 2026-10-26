import XCTest
@testable import Vervain

final class TrashRestorerTests: XCTestCase {

    private var root: URL!
    private var fakeTrash: URL!
    private var original: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("vervain-restore-\(UUID().uuidString)")
        fakeTrash = root.appendingPathComponent("trash")
        original = root.appendingPathComponent("docs")
        try FileManager.default.createDirectory(at: fakeTrash, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func trashedItem(named name: String, content: String = "x") throws -> TrashedItem {
        let inTrash = fakeTrash.appendingPathComponent(name)
        try Data(content.utf8).write(to: inTrash)
        return TrashedItem(name: name,
                           originalPath: original.appendingPathComponent(name).path,
                           trashPath: inTrash.path, size: 1, category: "Test")
    }

    func testRestoreMovesFileBackAndCreatesMissingFolder() throws {
        let item = try trashedItem(named: "a.txt")
        let restored = try TrashRestorer.restore(item)
        XCTAssertEqual(restored.path, original.appendingPathComponent("a.txt").path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: restored.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: item.trashPath!))
    }

    func testExistingFileIsNeverOverwritten() throws {
        try FileManager.default.createDirectory(at: original, withIntermediateDirectories: true)
        let existing = original.appendingPathComponent("a.txt")
        try Data("keep me".utf8).write(to: existing)

        let item = try trashedItem(named: "a.txt", content: "from trash")
        let restored = try TrashRestorer.restore(item)

        XCTAssertEqual(restored.lastPathComponent, "a (restored).txt")
        XCTAssertEqual(try String(contentsOf: existing, encoding: .utf8), "keep me")
        XCTAssertEqual(try String(contentsOf: restored, encoding: .utf8), "from trash")
    }

    func testMissingTrashItemThrowsNotInTrash() {
        let item = TrashedItem(name: "gone", originalPath: original.appendingPathComponent("gone").path,
                               trashPath: fakeTrash.appendingPathComponent("gone").path, size: 1, category: "T")
        XCTAssertThrowsError(try TrashRestorer.restore(item)) { error in
            XCTAssertEqual(error as? TrashRestorer.RestoreError, .notInTrash)
        }
        let unknown = TrashedItem(name: "x", originalPath: "/tmp/x", trashPath: nil, size: 1, category: "T")
        XCTAssertThrowsError(try TrashRestorer.restore(unknown))
    }

    func testRestoreAllReportsPartialSuccess() throws {
        let good = try trashedItem(named: "ok.txt")
        let bad = TrashedItem(name: "bad", originalPath: "/tmp/bad", trashPath: nil, size: 1, category: "T")
        let outcome = TrashRestorer.restoreAll([good, bad])
        XCTAssertEqual(outcome.restored, [good.id])
        XCTAssertEqual(outcome.failed, [bad.id])
    }

    func testUniqueDestinationCountsUp() throws {
        try FileManager.default.createDirectory(at: original, withIntermediateDirectories: true)
        let base = original.appendingPathComponent("f.txt")
        try Data().write(to: base)
        try Data().write(to: original.appendingPathComponent("f (restored).txt"))
        XCTAssertEqual(TrashRestorer.uniqueDestination(for: base).lastPathComponent, "f (restored 2).txt")
    }
}
