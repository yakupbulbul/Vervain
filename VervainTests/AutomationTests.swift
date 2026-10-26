import XCTest
@testable import Vervain

final class AutomationTests: XCTestCase {

    // MARK: Reminder schedule

    func testDefaultScheduleIsMondayTenAM() {
        let defaults = UserDefaults(suiteName: "vervain-rem-\(UUID().uuidString)")!
        let schedule = ReminderSchedule.fromDefaults(defaults)
        XCTAssertEqual(schedule, ReminderSchedule(weekday: 2, hour: 10))
        XCTAssertEqual(schedule.dateComponents.weekday, 2)
        XCTAssertEqual(schedule.dateComponents.hour, 10)
        XCTAssertEqual(schedule.dateComponents.minute, 0)
    }

    func testScheduleClampsOutOfRangeValues() {
        let defaults = UserDefaults(suiteName: "vervain-rem-\(UUID().uuidString)")!
        defaults.set(99, forKey: ReminderSchedule.weekdayKey)
        defaults.set(-4, forKey: ReminderSchedule.hourKey)
        XCTAssertEqual(ReminderSchedule.fromDefaults(defaults), ReminderSchedule(weekday: 7, hour: 0))
    }

    // MARK: Low disk policy

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testBelowThresholdNeverNotifies() {
        let usage = DiskUsage(total: 1_000, available: 200)   // 80 % used
        XCTAssertFalse(LowDiskPolicy.shouldNotify(usage: usage, thresholdPercent: 90, lastNotified: nil, now: now))
    }

    func testAtOrAboveThresholdNotifiesOnce() {
        let usage = DiskUsage(total: 1_000, available: 80)    // 92 % used
        XCTAssertTrue(LowDiskPolicy.shouldNotify(usage: usage, thresholdPercent: 90, lastNotified: nil, now: now))
        let recent = now.addingTimeInterval(-3_600)
        XCTAssertFalse(LowDiskPolicy.shouldNotify(usage: usage, thresholdPercent: 90, lastNotified: recent, now: now))
        let yesterday = now.addingTimeInterval(-LowDiskPolicy.cooldown - 1)
        XCTAssertTrue(LowDiskPolicy.shouldNotify(usage: usage, thresholdPercent: 90, lastNotified: yesterday, now: now))
    }

    func testExactlyAtThresholdCounts() {
        let usage = DiskUsage(total: 1_000, available: 100)   // 90 % used
        XCTAssertTrue(LowDiskPolicy.shouldNotify(usage: usage, thresholdPercent: 90, lastNotified: nil, now: now))
    }

    // MARK: Memory

    func testMemoryFractionIsClamped() {
        XCTAssertEqual(MemoryUsage(total: 100, used: 25).usedFraction, 0.25, accuracy: 0.0001)
        XCTAssertEqual(MemoryUsage(total: 100, used: 500).usedFraction, 1)
        XCTAssertEqual(MemoryUsage(total: 0, used: 5).usedFraction, 0)
    }

    func testKernelReportsSomeMemoryInUse() throws {
        let usage = try XCTUnwrap(MemoryUsage.current())
        XCTAssertGreaterThan(usage.total, 0)
        XCTAssertGreaterThan(usage.used, 0)
    }

    func testOwnProcessResidentSizeIsReadable() {
        let bytes = AppMemory.residentBytes(pid: ProcessInfo.processInfo.processIdentifier)
        XCTAssertNotNil(bytes)
        XCTAssertGreaterThan(bytes ?? 0, 0)
    }
}
