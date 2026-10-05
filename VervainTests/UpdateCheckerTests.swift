import XCTest
@testable import Vervain

final class UpdateCheckerTests: XCTestCase {

    func testNewerVersionsAreDetected() {
        XCTAssertTrue(UpdateChecker.isNewer("v2.0.1", than: "2.0.0"))
        XCTAssertTrue(UpdateChecker.isNewer("2.1", than: "2.0.9"))
        XCTAssertTrue(UpdateChecker.isNewer("3.0.0", than: "2.9.9"))
        XCTAssertTrue(UpdateChecker.isNewer("2.0.10", than: "2.0.9"))
    }

    func testEqualOrOlderVersionsAreNotNewer() {
        XCTAssertFalse(UpdateChecker.isNewer("v2.0.0", than: "2.0.0"))
        XCTAssertFalse(UpdateChecker.isNewer("2.0", than: "2.0.0"))
        XCTAssertFalse(UpdateChecker.isNewer("1.9.9", than: "2.0.0"))
    }

    func testPreReleaseSuffixesAreIgnoredNotCrashing() {
        XCTAssertFalse(UpdateChecker.isNewer("2.0.0-beta1", than: "2.0.0"))
        XCTAssertTrue(UpdateChecker.isNewer("2.1.0-rc1", than: "2.0.0"))
    }

    func testNormalizedStripsLeadingV() {
        XCTAssertEqual(UpdateChecker.normalized("v2.0.0"), "2.0.0")
        XCTAssertEqual(UpdateChecker.normalized("2.0.0"), "2.0.0")
    }
}
