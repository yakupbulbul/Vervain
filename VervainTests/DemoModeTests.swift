import XCTest
@testable import Vervain

final class DemoModeTests: XCTestCase {

    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("vervain-demo-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func makeApp(_ name: String, bundleID: String, in folder: URL) throws {
        let contents = folder.appendingPathComponent("\(name).app/Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "CFBundleIdentifier": bundleID,
            "CFBundleName": name,
            "CFBundleShortVersionString": "1.0"
        ]
        try (plist as NSDictionary).write(to: contents.appendingPathComponent("Info.plist"))
        try Data(count: 50_000).write(to: contents.appendingPathComponent("payload"))
    }

    // MARK: - Switch

    func test_off_whenVariableIsMissingOrEmpty() {
        XCTAssertNil(DemoMode.root(environment: [:]))
        XCTAssertNil(DemoMode.root(environment: [DemoMode.environmentKey: ""]))
    }

    func test_off_whenPathIsNotAFolder() throws {
        let file = root.appendingPathComponent("file.txt")
        try Data().write(to: file)
        XCTAssertNil(DemoMode.root(environment: [DemoMode.environmentKey: file.path]))
        XCTAssertNil(DemoMode.root(environment: [DemoMode.environmentKey: root.appendingPathComponent("nope").path]))
    }

    func test_on_forAnExistingFolder() {
        let url = DemoMode.root(environment: [DemoMode.environmentKey: root.path])
        XCTAssertEqual(url?.path, root.standardizedFileURL.path)
    }

    // MARK: - App Uninstaller

    func test_appScanner_listsOnlyDemoApps() async throws {
        let apps = root.appendingPathComponent("Applications")
        try makeApp("Lumen Notes", bundleID: "com.example.lumennotes", in: apps)
        try makeApp("Harbor VPN", bundleID: "com.example.harborvpn", in: apps)

        let found = try await AppScanner(demoRoot: root).scanInstalledApps()
        XCTAssertEqual(Set(found.map(\.name)), ["Lumen Notes", "Harbor VPN"])
    }

    func test_appScanner_findsLeftoversInDemoLibrary() async throws {
        let apps = root.appendingPathComponent("Applications")
        try makeApp("Lumen Notes", bundleID: "com.example.lumennotes", in: apps)
        let cache = root.appendingPathComponent("Library/Caches/com.example.lumennotes")
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        try Data(count: 80_000).write(to: cache.appendingPathComponent("blob"))

        let scanner = AppScanner(demoRoot: root)
        let app = try await scanner.scanInstalledApps().first!
        let withLeftovers = await scanner.scanLeftovers(for: app)
        XCTAssertEqual(withLeftovers.leftoverItems.map(\.url.lastPathComponent), ["com.example.lumennotes"])
    }

    // MARK: - Disk Analyzer

    func test_diskAnalyzer_measuresOnlyDemoFolders_andInventsNoDisk() async throws {
        for name in ["Projects", "Movies"] {
            let dir = root.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try Data(count: 100_000).write(to: dir.appendingPathComponent("file.bin"))
        }
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent(".hidden"), withIntermediateDirectories: true)

        let result = try await DiskAnalyzerService().analyzeWholeDisk(demoRoot: root)
        XCTAssertEqual(Set(result.root.children.map(\.name)), ["Projects", "Movies"])
        XCTAssertEqual(result.totalDiskBytes, 0)
        XCTAssertEqual(result.freeDiskBytes, 0)
        XCTAssertFalse(result.root.children.contains { $0.name == "System & Other" })
    }
}
