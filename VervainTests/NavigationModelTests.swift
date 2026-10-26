import XCTest
@testable import Vervain

@MainActor
final class NavigationModelTests: XCTestCase {

    func testShortcutNumbersMapToFeaturesInSidebarOrder() {
        XCTAssertEqual(NavigationModel.feature(forShortcutNumber: 1), AppFeature.allCases.first)
        XCTAssertNil(NavigationModel.feature(forShortcutNumber: 0))
        XCTAssertNil(NavigationModel.feature(forShortcutNumber: 10))
    }

    func testRescanRequestBumpsTick() {
        let nav = NavigationModel()
        let before = nav.rescanTick
        nav.requestRescan()
        XCTAssertEqual(nav.rescanTick, before + 1)
    }
}
