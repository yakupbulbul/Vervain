import XCTest
@testable import Vervain

final class CleanupServiceTrashTests: XCTestCase {

    func testTrashedFileIsRecordedAndCanBePutBack() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("vervain-trash-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("victim.bin")
        try Data(count: 8_192).write(to: file)

        let item = CleanupItem(url: file, size: 8_192, category: "Test", reason: .recentCache,
                               riskLevel: .safe, confidenceLevel: .high,
                               lastModifiedDate: nil, sourceModule: .systemJunk)
        var cat = CleanupCategory(kind: .oldCaches, title: "T", icon: "x",
                                  sourceModule: .systemJunk, items: [item])
        cat.selectAll()

        let result = try await CleanupService().execute([cat])
        try XCTSkipIf(result.successCount == 0, "Trash is not available in this environment")

        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        let record = try XCTUnwrap(result.trashed.first)
        XCTAssertEqual(record.originalPath, file.path)
        XCTAssertNotNil(record.trashPath)

        try TrashRestorer.restore(record)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }

    func testCancelledRunReportsPartialResult() async throws {
        let protected = CleanupItem(url: URL(fileURLWithPath: "/System"), size: 1, category: "T",
                                    reason: .custom("x"), riskLevel: .safe, confidenceLevel: .high,
                                    sourceModule: .systemJunk)
        var cat = CleanupCategory(kind: .oldCaches, title: "T", icon: "x",
                                  sourceModule: .systemJunk, items: [protected])
        cat.selectAll()
        let service = CleanupService()
        let task = Task { () -> CleanupResult in
            withUnsafeCurrentTask { $0?.cancel() }
            return try await service.execute([cat])
        }
        let result = try await task.value
        XCTAssertTrue(result.wasCancelled)
        XCTAssertTrue(result.trashed.isEmpty)
    }
}
