import XCTest
@testable import Vervain

final class ReviewFilterTests: XCTestCase {

    private func item(_ path: String, size: Int64 = 1, daysAgo: Int? = nil) -> CleanupItem {
        CleanupItem(url: URL(fileURLWithPath: path), size: size, category: "T", reason: .recentCache,
                    riskLevel: .review, confidenceLevel: .medium,
                    lastModifiedDate: daysAgo.map { Date(timeIntervalSinceNow: -Double($0) * 86_400) },
                    sourceModule: .largeOldFiles)
    }

    func testEmptyFilterKeepsEverythingInOrder() {
        let items = [item("/a/z.txt"), item("/a/b.txt")]
        let filter = ReviewFilter()
        XCTAssertFalse(filter.isActive)
        XCTAssertEqual(filter.apply(to: items).map(\.name), ["z.txt", "b.txt"])
    }

    func testQueryMatchesNameAndPathCaseInsensitively() {
        let items = [item("/Users/x/Movies/Holiday.MOV"), item("/Users/x/Docs/report.pdf")]
        var filter = ReviewFilter()
        filter.query = "holiday"
        XCTAssertEqual(filter.apply(to: items).map(\.name), ["Holiday.MOV"])
        filter.query = "docs"
        XCTAssertEqual(filter.apply(to: items).map(\.name), ["report.pdf"])
        XCTAssertTrue(filter.isActive)
    }

    func testKindFilter() {
        let items = [item("/a/clip.mp4"), item("/a/photo.heic"), item("/a/setup.dmg"), item("/a/notes.txt"), item("/a/blob.xyz")]
        var filter = ReviewFilter()
        filter.kind = .video
        XCTAssertEqual(filter.apply(to: items).map(\.name), ["clip.mp4"])
        filter.kind = .diskImage
        XCTAssertEqual(filter.apply(to: items).map(\.name), ["setup.dmg"])
        filter.kind = .other
        XCTAssertEqual(filter.apply(to: items).map(\.name), ["blob.xyz"])
    }

    func testSortOrders() {
        let items = [item("/a/b.bin", size: 5, daysAgo: 10), item("/a/a.bin", size: 50, daysAgo: 100), item("/a/c.bin", size: 1)]
        var filter = ReviewFilter()
        filter.sort = .sizeDescending
        XCTAssertEqual(filter.apply(to: items).map(\.name), ["a.bin", "b.bin", "c.bin"])
        filter.sort = .nameAscending
        XCTAssertEqual(filter.apply(to: items).map(\.name), ["a.bin", "b.bin", "c.bin"])
        filter.sort = .oldestFirst
        XCTAssertEqual(filter.apply(to: items).map(\.name), ["a.bin", "b.bin", "c.bin"])
    }

    func testSortAloneDoesNotCountAsActiveFilter() {
        var filter = ReviewFilter()
        filter.sort = .sizeDescending
        XCTAssertFalse(filter.isActive)
    }
}
