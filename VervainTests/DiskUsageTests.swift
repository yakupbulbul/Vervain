import XCTest
@testable import Vervain

final class DiskUsageTests: XCTestCase {

    func testUsedAndFraction() {
        let usage = DiskUsage(total: 1_000, available: 250)
        XCTAssertEqual(usage.used, 750)
        XCTAssertEqual(usage.usedFraction, 0.75, accuracy: 0.0001)
    }

    func testFractionIsClampedAndSafeForZeroTotal() {
        XCTAssertEqual(DiskUsage(total: 0, available: 0).usedFraction, 0)
        XCTAssertEqual(DiskUsage(total: 100, available: 500).usedFraction, 0)
    }

    func testCurrentVolumeIsReadable() {
        let usage = DiskUsage.current()
        XCTAssertNotNil(usage)
        XCTAssertGreaterThan(usage?.total ?? 0, 0)
    }
}
