import XCTest
@testable import Vervain

final class AppListFilterTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func app(_ name: String, size: Int64, usedDaysAgo: Int?, leftovers: Int64 = -1) -> AppInfo {
        var info = AppInfo.make(
            name: name, bundleID: "com.example.\(name.lowercased())", version: nil, developer: nil,
            url: URL(fileURLWithPath: "/Applications/\(name).app"), bundleSize: size,
            lastModifiedDate: now.addingTimeInterval(-400 * 86_400),
            lastUsedDate: usedDaysAgo.map { now.addingTimeInterval(-Double($0) * 86_400) })
        info.leftoverSize = leftovers
        return info
    }

    private var apps: [AppInfo] {
        [app("Beta", size: 200, usedDaysAgo: 10),
         app("Alpha", size: 900, usedDaysAgo: 400, leftovers: 50),
         app("Gamma", size: 50, usedDaysAgo: nil)]
    }

    func testDefaultSortIsLargestFirst() {
        XCTAssertEqual(AppListFilter().apply(to: apps, now: now).map(\.name), ["Alpha", "Beta", "Gamma"])
    }

    func testReversedFlipsOrder() {
        var filter = AppListFilter()
        filter.reversed = true
        XCTAssertEqual(filter.apply(to: apps, now: now).map(\.name), ["Gamma", "Beta", "Alpha"])
    }

    func testNameSortAndQuery() {
        var filter = AppListFilter()
        filter.sort = .name
        XCTAssertEqual(filter.apply(to: apps, now: now).map(\.name), ["Alpha", "Beta", "Gamma"])
        filter.query = "com.example.bet"
        XCTAssertEqual(filter.apply(to: apps, now: now).map(\.name), ["Beta"])
    }

    func testLastOpenedPutsLeastRecentFirstAndNeverOpenedLeads() {
        var filter = AppListFilter()
        filter.sort = .lastUsed
        XCTAssertEqual(filter.apply(to: apps, now: now).map(\.name), ["Gamma", "Alpha", "Beta"])
    }

    func testUnusedOnlyUsesLastOpenedThenBundleDate() {
        var filter = AppListFilter()
        filter.unusedOnly = true
        filter.unusedMonths = 6
        // Beta opened 10 days ago is used; Alpha (400 d) and Gamma (never opened,
        // bundle 400 d old) count as unused.
        XCTAssertEqual(Set(filter.apply(to: apps, now: now).map(\.name)), ["Alpha", "Gamma"])
    }

    func testLeftoversOnly() {
        var filter = AppListFilter()
        filter.leftoversOnly = true
        XCTAssertEqual(filter.apply(to: apps, now: now).map(\.name), ["Alpha"])
    }
}
