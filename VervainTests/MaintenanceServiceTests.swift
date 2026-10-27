import XCTest
@testable import Vervain

final class MaintenanceServiceTests: XCTestCase {

    func testCatalogCoversEveryTaskIDExactlyOnce() {
        XCTAssertEqual(MaintenanceTask.all.map(\.taskID), MaintenanceTaskID.allCases)
    }

    func testNoRunnableTaskNeedsAdministratorRights() {
        for task in MaintenanceTask.all {
            if case .run(let executable, let arguments) = task.action {
                XCTAssertTrue(FileManager.default.isExecutableFile(atPath: executable), executable)
                XCTAssertFalse(([executable] + arguments).contains("sudo"), task.title)
            }
        }
    }

    func testEveryTerminalCommandStartsWithSudoAndIsFixed() {
        let commands = MaintenanceTask.all.compactMap(\.terminalCommand)
        XCTAssertEqual(commands.count, 3)
        XCTAssertTrue(commands.allSatisfy { $0.hasPrefix("sudo ") })
    }

    func testRunnerRefusesTasksThatNeedTerminal() async {
        for id in [MaintenanceTaskID.flushDNS, .reindexSpotlight, .purgeMemory] {
            let outcome = await MaintenanceRunner().run(id)
            guard case .failed = outcome else { return XCTFail("\(id) must not run") }
        }
    }

    func testResetQuickLookRunsAndSucceeds() async {
        let outcome = await MaintenanceRunner().run(.resetQuickLook)
        XCTAssertEqual(outcome, .succeeded)
    }
}
