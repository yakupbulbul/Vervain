import XCTest
@testable import Vervain

@MainActor
final class AppUninstallerViewModelTests: XCTestCase {

    private func app(_ name: String, leftoverSize: Int64 = 100) -> AppInfo {
        var info = AppInfo.make(name: name, bundleID: "com.example.\(name.lowercased())", version: "1.0",
                                developer: nil, url: URL(fileURLWithPath: "/Applications/\(name).app"),
                                bundleSize: 1_000, lastModifiedDate: nil)
        info.leftoverSize = leftoverSize
        info.leftoverItems = [CleanupItem(
            url: URL(fileURLWithPath: "/Users/x/Library/Caches/com.example.\(name.lowercased())"),
            size: leftoverSize, category: "L", reason: .appLeftover(bundleID: info.bundleID),
            riskLevel: .safe, confidenceLevel: .high, sourceModule: .appUninstaller)]
        return info
    }

    func testBuildCategoriesPutsBundleFirstAndMarksItRisky() {
        let vm = AppUninstallerViewModel()
        let a = app("Alpha")
        vm.apps = [a]
        vm.selectedIDs = [a.id]
        let cats = vm.buildCleanupCategories()
        XCTAssertEqual(cats.count, 1)
        XCTAssertEqual(cats[0].items.count, 2)
        XCTAssertEqual(cats[0].items[0].riskLevel, .risky)
        XCTAssertEqual(cats[0].items[0].name, "Alpha")
        XCTAssertFalse(cats[0].items[0].isSelected, "the bundle must never be pre-selected")
    }

    func testTotalSelectedSizeIncludesLeftovers() {
        let vm = AppUninstallerViewModel()
        let a = app("Alpha", leftoverSize: 100), b = app("Beta", leftoverSize: 40)
        vm.apps = [a, b]
        vm.selectedIDs = [a.id]
        XCTAssertEqual(vm.totalSelectedSize, 1_100)
        vm.selectedIDs = [a.id, b.id]
        XCTAssertEqual(vm.totalSelectedSize, 2_140)
    }

    func testSelectAppAtURLMatchesScannedAppsOnly() {
        let vm = AppUninstallerViewModel()
        let a = app("Alpha")
        vm.apps = [a]
        XCTAssertEqual(vm.selectApp(at: URL(fileURLWithPath: "/Applications/Alpha.app"))?.id, a.id)
        XCTAssertTrue(vm.selectedIDs.contains(a.id))
        XCTAssertNil(vm.selectApp(at: URL(fileURLWithPath: "/Applications/Unknown.app")))
    }

    func testToggleSelectionFlipsMembership() {
        let vm = AppUninstallerViewModel()
        let a = app("Alpha")
        vm.apps = [a]
        vm.toggleSelection(a.id)
        XCTAssertTrue(vm.selectedIDs.contains(a.id))
        vm.toggleSelection(a.id)
        XCTAssertFalse(vm.selectedIDs.contains(a.id))
    }
}
