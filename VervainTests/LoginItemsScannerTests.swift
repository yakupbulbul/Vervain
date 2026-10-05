import XCTest
@testable import Vervain

final class LoginItemsScannerTests: XCTestCase {

    private var home: URL!

    override func setUpWithError() throws {
        home = FileManager.default.temporaryDirectory
            .appendingPathComponent("vervain-login-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: home.appendingPathComponent("Library/LaunchAgents"), withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: home)
    }

    private func writePlist(_ name: String, _ dict: [String: Any]) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
        try data.write(to: home.appendingPathComponent("Library/LaunchAgents/\(name)"))
    }

    func testParsesLabelProgramAndFlags() throws {
        try writePlist("com.example.helper.plist", [
            "Label": "com.example.helper",
            "ProgramArguments": ["/Applications/Example.app/helper", "--flag"],
            "RunAtLoad": true,
        ])
        let url = home.appendingPathComponent("Library/LaunchAgents/com.example.helper.plist")
        let item = LoginItemsScanner.parse(plistAt: url, scope: .userAgent)
        XCTAssertEqual(item?.label, "com.example.helper")
        XCTAssertEqual(item?.program, "/Applications/Example.app/helper")
        XCTAssertEqual(item?.runsAtLoad, true)
        XCTAssertEqual(item?.isRemovable, true)
    }

    func testSkipsAppleItemsAndInvalidPlists() async throws {
        try writePlist("com.apple.thing.plist", ["Label": "com.apple.thing"])
        try writePlist("com.example.ok.plist", ["Label": "com.example.ok"])
        try Data("not a plist".utf8).write(
            to: home.appendingPathComponent("Library/LaunchAgents/broken.plist"))

        let empty = home.appendingPathComponent("nonexistent-root")
        let items = try await LoginItemsScanner().scan(home: home, systemRoot: empty)
        XCTAssertEqual(items.map(\.label), ["com.example.ok"])
    }

    func testSystemItemsAreNotRemovable() {
        let url = URL(fileURLWithPath: "/Library/LaunchDaemons/x.plist")
        let item = LoginItem(id: url.path, label: "x", program: nil, plistURL: url,
                             scope: .systemDaemon, runsAtLoad: false, isDisabled: false)
        XCTAssertFalse(item.isRemovable)
    }
}
