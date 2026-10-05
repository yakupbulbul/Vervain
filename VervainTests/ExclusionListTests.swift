import XCTest
@testable import Vervain

final class ExclusionListTests: XCTestCase {

    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "vervain-excl-\(UUID().uuidString)")!
    }

    func testAddRemoveAndDeduplicate() {
        let d = defaults()
        ExclusionList.add("/Users/tester/Projects", to: d)
        ExclusionList.add("/Users/tester/Projects/", to: d)
        XCTAssertEqual(ExclusionList.paths(d), ["/Users/tester/Projects"])
        ExclusionList.remove("/Users/tester/Projects", from: d)
        XCTAssertTrue(ExclusionList.paths(d).isEmpty)
    }

    func testRootCannotBeExcludedAsEverything() {
        let d = defaults()
        ExclusionList.add("/", to: d)
        XCTAssertTrue(ExclusionList.paths(d).isEmpty)
    }

    func testMatchesPathAndDescendantsButNotSiblings() {
        let ex = ["/Users/tester/Projects"]
        XCTAssertTrue(ExclusionList.isExcluded(URL(fileURLWithPath: "/Users/tester/Projects"), excluded: ex))
        XCTAssertTrue(ExclusionList.isExcluded(URL(fileURLWithPath: "/Users/tester/Projects/a/b.txt"), excluded: ex))
        XCTAssertFalse(ExclusionList.isExcluded(URL(fileURLWithPath: "/Users/tester/Projects-old/a"), excluded: ex))
    }

    @MainActor
    func testApplyExclusionsDropsItemsAndEmptyCategories() {
        func item(_ path: String) -> CleanupItem {
            CleanupItem(url: URL(fileURLWithPath: path), size: 1, category: "T", reason: .recentCache,
                        riskLevel: .safe, confidenceLevel: .high, sourceModule: .systemJunk)
        }
        let keep = CleanupCategory(kind: .oldCaches, title: "keep", icon: "x", sourceModule: .systemJunk,
                                   items: [item("/a/ok"), item("/skip/x")])
        let gone = CleanupCategory(kind: .oldLogs, title: "gone", icon: "x", sourceModule: .systemJunk,
                                   items: [item("/skip/y")])
        let out = ModuleScanViewModel.applyExclusions([keep, gone], excluded: ["/skip"])
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[0].items.count, 1)
    }
}
