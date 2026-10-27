import XCTest
@testable import Vervain

final class HealthScoreBreakdownTests: XCTestCase {

    private let GB: Int64 = 1_000_000_000

    // MARK: - No deductions

    func test_perfectMac_returns100() {
        let b = HealthScoreBreakdown.compute(
            safeJunkBytes: 0, diskUsageFraction: 0.50, appCount: 30)
        XCTAssertEqual(b.finalScore, 100)
        XCTAssertEqual(b.potentialScore, 100)
        XCTAssertEqual(b.tier, .good)
        XCTAssertTrue(b.deductions.isEmpty)
    }

    // MARK: - Junk is a smooth ramp, not a staircase

    func test_junkUnderHalfGB_costsNothing() {
        XCTAssertEqual(HealthScoreBreakdown.junkPenalty(safeBytes: GB / 2, reviewBytes: 0), 0)
    }

    func test_junkPenalty_growsWithoutJumps() {
        var previous = 0.0
        for tenthGB in stride(from: 0, through: 200, by: 1) {
            let p = HealthScoreBreakdown.junkPenalty(safeBytes: Int64(tenthGB) * GB / 10, reviewBytes: 0)
            XCTAssertGreaterThanOrEqual(p, previous)
            XCTAssertLessThan(p - previous, 0.5, "No cliff between neighbouring sizes")
            previous = p
        }
    }

    func test_junkPenalty_capsAtMax() {
        XCTAssertEqual(HealthScoreBreakdown.junkPenalty(safeBytes: 15 * GB, reviewBytes: 0), 35, accuracy: 0.001)
        XCTAssertEqual(HealthScoreBreakdown.junkPenalty(safeBytes: 500 * GB, reviewBytes: 0), 35, accuracy: 0.001)
    }

    func test_reviewJunkWeighsLessThanSafeJunk() {
        let safe = HealthScoreBreakdown.junkPenalty(safeBytes: 8 * GB, reviewBytes: 0)
        let review = HealthScoreBreakdown.junkPenalty(safeBytes: 0, reviewBytes: 8 * GB)
        XCTAssertLessThan(review, safe)
        XCTAssertGreaterThan(review, 0)
    }

    // MARK: - Storage pressure

    func test_diskUnder75Percent_costsNothing() {
        XCTAssertEqual(HealthScoreBreakdown.storagePenalty(usedFraction: 0.75, freeBytes: nil), 0)
    }

    func test_fullDisk_withoutFreeFigure_usesShareOnly() {
        XCTAssertEqual(HealthScoreBreakdown.storagePenalty(usedFraction: 0.97, freeBytes: nil), 40, accuracy: 0.001)
    }

    func test_fullButRoomyDisk_isNotPunished() {
        // 96% of a 4 TB drive is still 160 GB free.
        XCTAssertEqual(HealthScoreBreakdown.storagePenalty(usedFraction: 0.96, freeBytes: 160 * GB), 0)
    }

    func test_fullAndCrampedDisk_isPunishedHard() {
        XCTAssertEqual(HealthScoreBreakdown.storagePenalty(usedFraction: 0.96, freeBytes: 18 * GB), 36, accuracy: 4)
    }

    func test_almostNoFreeSpace_isMaxEvenOnBigDisk() {
        XCTAssertEqual(HealthScoreBreakdown.storagePenalty(usedFraction: 0.5, freeBytes: 2 * GB), 40, accuracy: 0.001)
    }

    func test_storagePenalty_neverExceedsMax() {
        for used in stride(from: 0.0, through: 1.0, by: 0.05) {
            for free in [0, 1, 5, 10, 50, 100, 500].map({ Int64($0) * GB }) {
                let p = HealthScoreBreakdown.storagePenalty(usedFraction: used, freeBytes: free)
                XCTAssertTrue((0...40).contains(p))
            }
        }
    }

    // MARK: - Apps

    func test_appPenalty_rampsBetween100And200() {
        XCTAssertEqual(HealthScoreBreakdown.appsPenalty(count: 100), 0)
        XCTAssertEqual(HealthScoreBreakdown.appsPenalty(count: 150), 2.5, accuracy: 0.001)
        XCTAssertEqual(HealthScoreBreakdown.appsPenalty(count: 400), 5, accuracy: 0.001)
    }

    // MARK: - Combined

    func test_worstCase_leavesFloorOf20() {
        let b = HealthScoreBreakdown.compute(
            safeJunkBytes: 50 * GB, reviewJunkBytes: 50 * GB,
            diskUsageFraction: 0.99, diskFreeBytes: GB, appCount: 250)
        XCTAssertEqual(b.finalScore, 20)
        XCTAssertEqual(b.tier, .critical)
    }

    func test_finalScore_isBaseMinusShownPoints() {
        let b = HealthScoreBreakdown.compute(
            safeJunkBytes: 6 * GB, reviewJunkBytes: 3 * GB,
            diskUsageFraction: 0.9, diskFreeBytes: 40 * GB, appCount: 140)
        XCTAssertEqual(b.finalScore, b.baseScore - b.deductions.reduce(0) { $0 + $1.points })
        XCTAssertTrue(b.deductions.allSatisfy { $0.points > 0 })
    }

    func test_neverGoesNegative() {
        let b = HealthScoreBreakdown.compute(
            safeJunkBytes: 100 * GB, reviewJunkBytes: 100 * GB,
            diskUsageFraction: 1.0, diskFreeBytes: 0, appCount: 9999)
        XCTAssertGreaterThanOrEqual(b.finalScore, 0)
    }

    // MARK: - Potential score

    func test_cleaningSafeJunk_raisesTheScore() {
        let b = HealthScoreBreakdown.compute(
            safeJunkBytes: 12 * GB, diskUsageFraction: 0.9, diskFreeBytes: 40 * GB, appCount: 50)
        XCTAssertGreaterThan(b.potentialScore, b.finalScore)
        XCTAssertEqual(b.potentialGain, b.potentialScore - b.finalScore)
    }

    func test_reviewOnlyJunk_isNotPromisedAsGain() {
        // Nothing here is safe to remove, so cleaning cannot be promised to help.
        let b = HealthScoreBreakdown.compute(
            safeJunkBytes: 0, reviewJunkBytes: 20 * GB, diskUsageFraction: 0.5, appCount: 10)
        XCTAssertEqual(b.potentialScore, b.finalScore)
        XCTAssertEqual(b.potentialGain, 0)
    }

    func test_potentialNeverBelowFinal() {
        for safe in [0, 1, 5, 20].map({ Int64($0) * GB }) {
            let b = HealthScoreBreakdown.compute(
                safeJunkBytes: safe, diskUsageFraction: 0.95, diskFreeBytes: 10 * GB, appCount: 120)
            XCTAssertGreaterThanOrEqual(b.potentialScore, b.finalScore)
        }
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
