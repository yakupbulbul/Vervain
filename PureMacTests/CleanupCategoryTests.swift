import XCTest
@testable import PureMac

final class CleanupCategoryTests: XCTestCase {

    private func makeItem(
        risk: CleanupRiskLevel,
        confidence: CleanupConfidenceLevel = .high,
        size: Int64 = 100,
        reason: CleanupReason = .oldCache(ageDays: 60)
    ) -> CleanupItem {
        CleanupItem(
            url: URL(fileURLWithPath: "/tmp/test_\(UUID())"),
            size: size,
            category: "Test",
            reason: reason,
            riskLevel: risk,
            confidenceLevel: confidence,
            sourceModule: .systemJunk
        )
    }

    // MARK: - Totals

    func test_totalSize_sumsAllItems() {
        let cat = CleanupCategory(
            title: "Test", icon: "doc", sourceModule: .systemJunk,
            items: [
                makeItem(risk: .safe, size: 100),
                makeItem(risk: .safe, size: 200),
                makeItem(risk: .safe, size: 300),
            ])
        XCTAssertEqual(cat.totalSize, 600)
    }

    func test_selectedSize_onlyCountsSelected() {
        var cat = CleanupCategory(
            title: "Test", icon: "doc", sourceModule: .systemJunk,
            items: [
                makeItem(risk: .safe, size: 100),  // auto-on
                makeItem(risk: .risky, size: 200), // auto-off
            ])
        XCTAssertEqual(cat.selectedSize, 100)
        cat.selectAll()
        XCTAssertEqual(cat.selectedSize, 300)
    }

    // MARK: - Selection helpers

    func test_toggleItem_flipsSingleItem() {
        var cat = CleanupCategory(
            title: "Test", icon: "doc", sourceModule: .systemJunk,
            items: [makeItem(risk: .safe)])
        XCTAssertTrue(cat.items[0].isSelected, "Safe/high auto-on")
        cat.toggle(itemID: cat.items[0].id)
        XCTAssertFalse(cat.items[0].isSelected)
    }

    func test_resetToDefaults_appliesPolicy() {
        var cat = CleanupCategory(
            title: "Test", icon: "doc", sourceModule: .systemJunk,
            items: [
                makeItem(risk: .risky),  // off
                makeItem(risk: .safe),   // on
            ])
        cat.selectAll()
        XCTAssertTrue(cat.items[0].isSelected)
        cat.resetToDefaults()
        XCTAssertFalse(cat.items[0].isSelected, "Risky reset to off")
        XCTAssertTrue(cat.items[1].isSelected,  "Safe reset to on")
    }

    func test_maxSelectedRisk_returnsHighest() {
        var cat = CleanupCategory(
            title: "Test", icon: "doc", sourceModule: .systemJunk,
            items: [
                makeItem(risk: .safe),
                makeItem(risk: .review),
                makeItem(risk: .risky),
            ])
        cat.selectAll()
        XCTAssertEqual(cat.maxSelectedRisk, .risky)
    }

    // MARK: - CleanupItem display path

    func test_displayPath_replacesHome() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let url = home.appendingPathComponent("Downloads/file.txt")
        let display = CleanupItem.makeDisplayPath(url: url)
        XCTAssertTrue(display.hasPrefix("~/"), "Got \(display)")
    }
}
