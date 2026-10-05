import XCTest
@testable import Vervain

final class CleanupServiceSafetyTests: XCTestCase {

    private let home = URL(fileURLWithPath: "/Users/tester")

    private func safe(_ path: String) -> Bool {
        CleanupService.isSafeToTrash(URL(fileURLWithPath: path), home: home)
    }

    func testRejectsSystemRoots() {
        for path in ["/", "/System", "/System/Library/Foo", "/usr/bin/ls", "/Library", "/Applications", "/Users"] {
            XCTAssertFalse(safe(path), path)
        }
    }

    func testRejectsHomeAndUserFolders() {
        for name in ["", "/Library", "/Documents", "/Desktop", "/Downloads", "/.Trash"] {
            XCTAssertFalse(safe("/Users/tester" + name), name)
        }
    }

    func testRejectsTraversalIntoProtectedPath() {
        XCTAssertFalse(safe("/Users/tester/Library/Caches/../../Documents"))
    }

    func testAllowsRegularTargets() {
        XCTAssertTrue(safe("/Users/tester/Library/Caches/com.example.app"))
        XCTAssertTrue(safe("/Users/tester/Downloads/old.dmg"))
        XCTAssertTrue(safe("/Applications/Example.app"))
    }

    func testRejectsNonFileURL() {
        XCTAssertFalse(CleanupService.isSafeToTrash(URL(string: "https://example.com/a")!, home: home))
    }
}
