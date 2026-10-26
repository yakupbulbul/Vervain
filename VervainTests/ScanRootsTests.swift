import XCTest
@testable import Vervain

final class ScanRootsTests: XCTestCase {

    private let home = URL(fileURLWithPath: "/Users/tester")

    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "vervain-roots-\(UUID().uuidString)")!
    }

    func testPersonalFoldersAreAlwaysIncluded() {
        let paths = ScanRoots.all(defaults: defaults(), home: home).map(\.path)
        XCTAssertTrue(paths.contains("/Users/tester/Documents"))
        XCTAssertTrue(paths.contains("/Users/tester/Downloads"))
    }

    func testExtrasAreAddedOnceAndRootIsRejected() {
        let d = defaults()
        ScanRoots.add("/Volumes/Data/Projects", to: d)
        ScanRoots.add("/Volumes/Data/Projects/", to: d)
        ScanRoots.add("/", to: d)
        XCTAssertEqual(ScanRoots.extras(d), ["/Volumes/Data/Projects"])
        XCTAssertTrue(ScanRoots.all(defaults: d, home: home).map(\.path).contains("/Volumes/Data/Projects"))
    }

    func testOverlappingRootsAreMerged() {
        let d = defaults()
        ScanRoots.add("/Users/tester/Documents/Work", to: d)   // already inside Documents
        ScanRoots.add("/Users/tester", to: d)                   // contains every personal folder
        let paths = ScanRoots.all(defaults: d, home: home).map(\.path)
        XCTAssertEqual(paths, ["/Users/tester"])
    }

    func testRemove() {
        let d = defaults()
        ScanRoots.add("/Volumes/X", to: d)
        ScanRoots.remove("/Volumes/X", from: d)
        XCTAssertTrue(ScanRoots.extras(d).isEmpty)
    }
}
