import XCTest
@testable import Vervain

final class DiskAnalyzerServiceTests: XCTestCase {

    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("vervain-disk-\(UUID().uuidString)")
        let deep = root.appendingPathComponent("a/b/c/d")
        try FileManager.default.createDirectory(at: deep, withIntermediateDirectories: true)
        try Data(count: 50_000).write(to: root.appendingPathComponent("top.bin"))
        try Data(count: 80_000).write(to: root.appendingPathComponent("a/mid.bin"))
        try Data(count: 120_000).write(to: deep.appendingPathComponent("deep.bin"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testDepthLimitDoesNotChangeTotalSize() async throws {
        let shallow = try await DiskAnalyzerService().analyze(root: root, maxDepth: 1)
        let deep = try await DiskAnalyzerService().analyze(root: root, maxDepth: 10)
        XCTAssertGreaterThan(deep.root.size, 0)
        XCTAssertEqual(shallow.root.size, deep.root.size,
                       "folders below the depth limit must still be counted")
    }

    func testTotalCoversAllFiles() async throws {
        let result = try await DiskAnalyzerService().analyze(root: root, maxDepth: 10)
        XCTAssertGreaterThanOrEqual(result.root.size, 250_000)
        XCTAssertEqual(result.largestFiles.first?.name, "deep.bin")
    }

    func testChildrenAreSortedLargestFirst() async throws {
        let result = try await DiskAnalyzerService().analyze(root: root, maxDepth: 10)
        let sizes = result.root.children.map(\.size)
        XCTAssertEqual(sizes, sizes.sorted(by: >))
    }
}

@MainActor
final class DiskAnalyzerViewModelTests: XCTestCase {

    func testPruneRemovesMissingNodesAndShrinksSizes() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("vervain-prune-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let kept = dir.appendingPathComponent("kept.bin")
        try Data(count: 10).write(to: kept)

        let keptNode = DiskNode(url: kept, name: "kept.bin", size: 100, children: [], isDirectory: false)
        let goneNode = DiskNode(url: dir.appendingPathComponent("gone.bin"), name: "gone.bin",
                                size: 400, children: [], isDirectory: false)
        let root = DiskNode(url: dir, name: "root", size: 500, children: [keptNode, goneNode], isDirectory: true)

        let removed = DiskAnalyzerViewModel.prune(root)
        XCTAssertEqual(removed, 400)
        XCTAssertEqual(root.size, 100)
        XCTAssertEqual(root.children.map(\.name), ["kept.bin"])
    }

    func testLargeFileCategoryRecordsModificationDate() throws {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("vervain-large-\(UUID().uuidString).bin")
        try Data(count: 10).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        let vm = DiskAnalyzerViewModel()
        let node = DiskNode(url: file, name: file.lastPathComponent, size: 10, children: [], isDirectory: false)
        vm.largestFiles = [node]
        vm.selectedFileIDs = [node.id]
        let cats = vm.buildLargeFileCleanupCategory()
        XCTAssertNotNil(cats.first?.items.first?.lastModifiedDate,
                        "without a date the changed-since-scan guard cannot protect these files")
    }

    func testReviewCategoryForFolderIsReviewRiskAndNotPreselected() {
        let vm = DiskAnalyzerViewModel()
        let folder = DiskNode(url: URL(fileURLWithPath: "/tmp/some-folder"), name: "some-folder",
                              size: 5_000, children: [], isDirectory: true)
        let cats = vm.reviewCategories(for: folder)
        XCTAssertEqual(cats.count, 1)
        XCTAssertEqual(cats[0].items.count, 1)
        XCTAssertEqual(cats[0].items[0].riskLevel, .review)
        XCTAssertFalse(cats[0].items[0].isSelected)
    }
}
