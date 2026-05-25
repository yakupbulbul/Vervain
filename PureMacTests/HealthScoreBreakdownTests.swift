import XCTest
@testable import PureMac

final class HealthScoreBreakdownTests: XCTestCase {

    // MARK: - No deductions

    func test_perfectMac_returns100() {
        let b = HealthScoreBreakdown.compute(
            junkBytes: 0,
            diskUsageFraction: 0.50,
            appCount: 30)
        XCTAssertEqual(b.finalScore, 100)
        XCTAssertEqual(b.tier, .good)
        XCTAssertTrue(b.deductions.isEmpty)
    }

    // MARK: - Junk thresholds (only the highest band applies)

    func test_junkExactly1GB_noDeduction() {
        let b = HealthScoreBreakdown.compute(
            junkBytes: 1_000_000_000,
            diskUsageFraction: 0.5, appCount: 0)
        XCTAssertEqual(b.finalScore, 100, "1 GB exact is boundary; > applies")
    }

    func test_junkOver1GB_deducts10() {
        let b = HealthScoreBreakdown.compute(
            junkBytes: 2_000_000_000,
            diskUsageFraction: 0.5, appCount: 0)
        XCTAssertEqual(b.finalScore, 90)
    }

    func test_junkOver5GB_deducts30() {
        let b = HealthScoreBreakdown.compute(
            junkBytes: 6_000_000_000,
            diskUsageFraction: 0.5, appCount: 0)
        XCTAssertEqual(b.finalScore, 70)
    }

    func test_junkOver10GB_deducts40() {
        let b = HealthScoreBreakdown.compute(
            junkBytes: 12_000_000_000,
            diskUsageFraction: 0.5, appCount: 0)
        XCTAssertEqual(b.finalScore, 60)
    }

    func test_onlyHighestJunkBandApplies() {
        // 12 GB should give -40, not -40 + -30 + -10.
        let b = HealthScoreBreakdown.compute(
            junkBytes: 12_000_000_000,
            diskUsageFraction: 0.5, appCount: 0)
        XCTAssertEqual(b.deductions.count, 1, "Only the most severe junk band applies")
    }

    // MARK: - Disk thresholds

    func test_diskOver80_deducts20() {
        let b = HealthScoreBreakdown.compute(
            junkBytes: 0, diskUsageFraction: 0.85, appCount: 0)
        XCTAssertEqual(b.finalScore, 80)
    }

    func test_diskOver90_deducts30() {
        let b = HealthScoreBreakdown.compute(
            junkBytes: 0, diskUsageFraction: 0.95, appCount: 0)
        XCTAssertEqual(b.finalScore, 70)
    }

    // MARK: - App count

    func test_over100Apps_deducts10() {
        let b = HealthScoreBreakdown.compute(
            junkBytes: 0, diskUsageFraction: 0.5, appCount: 150)
        XCTAssertEqual(b.finalScore, 90)
    }

    // MARK: - Combined

    func test_worstCaseCompounds_butFloorsAtZero() {
        // 40 (junk) + 30 (disk) + 10 (apps) + 5 (leftovers) + 5 (downloads) = 90
        let b = HealthScoreBreakdown.compute(
            junkBytes: 50_000_000_000,
            diskUsageFraction: 0.99,
            appCount: 250,
            leftoverCount: 50,
            oldDownloadBytes: 5_000_000_000)
        XCTAssertEqual(b.finalScore, 10, "Combined deductions reduce score")
        XCTAssertEqual(b.tier, .critical)
    }

    func test_neverGoesNegative() {
        // Pathological inputs that would over-subtract.
        let b = HealthScoreBreakdown.compute(
            junkBytes: 100_000_000_000,
            diskUsageFraction: 1.0,
            appCount: 9999,
            leftoverCount: 9999,
            oldDownloadBytes: 100_000_000_000)
        XCTAssertGreaterThanOrEqual(b.finalScore, 0)
    }

    // MARK: - Tier mapping

    func test_tierBoundaries() {
        XCTAssertEqual(HealthScore(value: 100).tier, .good)
        XCTAssertEqual(HealthScore(value: 80).tier,  .good)
        XCTAssertEqual(HealthScore(value: 79).tier,  .warning)
        XCTAssertEqual(HealthScore(value: 50).tier,  .warning)
        XCTAssertEqual(HealthScore(value: 49).tier,  .critical)
        XCTAssertEqual(HealthScore(value: 0).tier,   .critical)
    }
}
