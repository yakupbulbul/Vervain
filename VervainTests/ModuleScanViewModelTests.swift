import XCTest
@testable import Vervain

@MainActor
final class ModuleScanViewModelTests: XCTestCase {

    private func category(_ title: String, paths: [String]) -> CleanupCategory {
        let items = paths.map {
            CleanupItem(url: URL(fileURLWithPath: $0), size: 10, category: "T", reason: .recentCache,
                        riskLevel: .safe, confidenceLevel: .high, sourceModule: .systemJunk)
        }
        return CleanupCategory(kind: .oldCaches, title: title, icon: "x", sourceModule: .systemJunk, items: items)
    }

    private func waitUntil(_ condition: @autoclosure () -> Bool, timeout: TimeInterval = 3) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline { try? await Task.sleep(nanoseconds: 20_000_000) }
    }

    func testScanPublishesResultsFromTheScannerClosure() async {
        let vm = ModuleScanViewModel {
            var meta = ScanMetadata()
            meta.scannedCount = 2
            return ([CleanupCategory(kind: .oldCaches, title: "A", icon: "x", sourceModule: .systemJunk, items: [])], meta)
        }
        XCTAssertEqual(vm.state, .idle)
        vm.scan()
        await waitUntil(vm.state == .results)
        XCTAssertEqual(vm.state, .results)
        XCTAssertEqual(vm.categories.map(\.title), ["A"])
        XCTAssertEqual(vm.metadata.scannedCount, 2)
    }

    func testScannerErrorBecomesErrorState() async {
        struct Boom: Error {}
        let vm = ModuleScanViewModel { throw Boom() }
        vm.scan()
        await waitUntil({ if case .error = vm.state { return true } else { return false } }())
        if case .error = vm.state {} else { XCTFail("expected the error state, got \(vm.state)") }
    }

    func testToggleCategorySelectsAndDeselects() async {
        let cat = category("A", paths: ["/x/1", "/x/2"])
        let vm = ModuleScanViewModel { ([cat], ScanMetadata()) }
        vm.scan()
        await waitUntil(vm.state == .results)
        let id = vm.categories[0].id
        vm.toggleCategory(id)
        XCTAssertTrue(vm.categories[0].allSelected || vm.categories[0].noneSelected)
        let after = vm.categories[0].allSelected
        vm.toggleCategory(id)
        XCTAssertNotEqual(vm.categories[0].allSelected, after)
    }

    func testApplyExclusionsKeepsCategoriesWithRemainingItems() {
        let cats = [category("Keep", paths: ["/a/1", "/skip/2"]), category("Drop", paths: ["/skip/3"])]
        let out = ModuleScanViewModel.applyExclusions(cats, excluded: ["/skip"])
        XCTAssertEqual(out.map(\.title), ["Keep"])
        XCTAssertEqual(out[0].items.count, 1)
    }
}

@MainActor
final class LoginItemsViewModelTests: XCTestCase {

    private func item(_ label: String, scope: LoginItem.Scope) -> LoginItem {
        let url = URL(fileURLWithPath: "/tmp/\(label).plist")
        return LoginItem(id: url.path, label: label, program: "/Applications/\(label).app/run",
                         plistURL: url, scope: scope, runsAtLoad: true, isDisabled: false)
    }

    func testOnlyUserAgentsCanBeSelectedAndReviewed() {
        let vm = LoginItemsViewModel()
        let user = item("user", scope: .userAgent), system = item("system", scope: .systemDaemon)
        vm.items = [user, system]
        vm.toggle(user)
        vm.toggle(system)
        XCTAssertEqual(vm.selectedIDs, [user.id])
        let cats = vm.buildCleanupCategories()
        XCTAssertEqual(cats.count, 1)
        XCTAssertEqual(cats[0].items.map(\.name), ["user"])
        XCTAssertFalse(cats[0].items[0].isSelected, "review-risk items are never pre-selected")
    }

    func testGroupedKeepsScopeOrderAndDropsEmptyGroups() {
        let vm = LoginItemsViewModel()
        vm.items = [item("d", scope: .systemDaemon), item("u", scope: .userAgent)]
        XCTAssertEqual(vm.grouped().map(\.scope), [.userAgent, .systemDaemon])
    }

    func testNothingSelectedMeansNoCategories() {
        let vm = LoginItemsViewModel()
        vm.items = [item("u", scope: .userAgent)]
        XCTAssertTrue(vm.buildCleanupCategories().isEmpty)
    }
}
