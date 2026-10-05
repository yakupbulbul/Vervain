import XCTest
@testable import Vervain

final class ReportExporterTests: XCTestCase {

    private func category() -> CleanupCategory {
        let tricky = CleanupItem(url: URL(fileURLWithPath: "/tmp/a,b \"c\".txt"), size: 1_234, category: "T",
                                 reason: .recentCache, riskLevel: .safe, confidenceLevel: .high,
                                 sourceModule: .systemJunk)
        return CleanupCategory(kind: .oldCaches, title: "Old, Caches", icon: "x",
                               sourceModule: .systemJunk, items: [tricky])
    }

    func testEscapeFollowsRFC4180() {
        XCTAssertEqual(ReportExporter.escape("plain"), "plain")
        XCTAssertEqual(ReportExporter.escape("a,b"), "\"a,b\"")
        XCTAssertEqual(ReportExporter.escape("say \"hi\""), "\"say \"\"hi\"\"\"")
        XCTAssertEqual(ReportExporter.escape("two\nlines"), "\"two\nlines\"")
    }

    func testCSVHasHeaderAndOneRowPerItem() {
        let csv = ReportExporter.csv(for: [category()])
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].hasPrefix("Category,Name,Path,Size (bytes)"))
        XCTAssertTrue(lines[1].hasPrefix("\"Old, Caches\""))
        XCTAssertTrue(lines[1].contains(",1234,safe,high,"))
        XCTAssertTrue(lines[1].hasSuffix(",yes"))
    }

    func testMarkdownListsCategoriesAndItems() {
        let md = ReportExporter.markdown(for: [category()], title: "Report")
        XCTAssertTrue(md.hasPrefix("# Report"))
        XCTAssertTrue(md.contains("## Old, Caches"))
        XCTAssertTrue(md.contains("safe"))
    }

    func testEmptyReportIsJustTheHeader() {
        XCTAssertEqual(ReportExporter.csv(for: []).split(separator: "\n").count, 1)
    }
}
