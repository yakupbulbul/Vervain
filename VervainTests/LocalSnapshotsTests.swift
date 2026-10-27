import XCTest
@testable import Vervain

final class LocalSnapshotsTests: XCTestCase {

    private let utc = TimeZone(identifier: "UTC")!

    func testParsesDateStampsAndIgnoresTheHeader() {
        let output = """
        Snapshot dates for disk /:
        2026-10-26-091500
        2026-10-27-001234
        """
        let snapshots = LocalSnapshotParser.parse(output, timeZone: utc)
        XCTAssertEqual(snapshots.map(\.name), ["2026-10-27-001234", "2026-10-26-091500"], "newest first")
    }

    func testParsedDateMatchesTheStamp() throws {
        let snapshot = try XCTUnwrap(LocalSnapshotParser.parse("2026-10-27-001234", timeZone: utc).first)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: snapshot.date)
        XCTAssertEqual([parts.year, parts.month, parts.day, parts.hour, parts.minute, parts.second],
                       [2026, 10, 27, 0, 12, 34])
    }

    func testRejectsAnythingThatIsNotExactlyADateStamp() {
        let output = """
        2026-10-27-001234; rm -rf ~
        $(whoami)
        2026-10-27-0012
        com.apple.TimeMachine.2026-10-27-001234.local
        2026-13-45-999999
        """
        XCTAssertTrue(LocalSnapshotParser.parse(output, timeZone: utc).isEmpty)
    }

    func testEmptyOutputGivesNoSnapshots() {
        XCTAssertTrue(LocalSnapshotParser.parse("Snapshot dates for disk /:\n", timeZone: utc).isEmpty)
    }

    func testDeleteCommandNamesTheSnapshot() throws {
        let snapshot = try XCTUnwrap(LocalSnapshotParser.parse("2026-10-27-001234", timeZone: utc).first)
        XCTAssertEqual(snapshot.deleteCommand, "sudo tmutil deletelocalsnapshots 2026-10-27-001234")
    }

    func testPurgeableSpaceNeverGoesNegative() {
        XCTAssertEqual(LocalSnapshotParser.purgeableBytes(availableForImportantUse: 50, available: 20), 30)
        XCTAssertEqual(LocalSnapshotParser.purgeableBytes(availableForImportantUse: 10, available: 20), 0)
    }

    func testServiceReportsWithoutCrashingOnThisMachine() async {
        let report = await LocalSnapshotsService().report()
        XCTAssertGreaterThanOrEqual(report.purgeableBytes, 0)
    }
}
