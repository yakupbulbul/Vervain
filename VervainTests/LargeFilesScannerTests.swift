import XCTest
@testable import Vervain

final class LargeFilesScannerTests: XCTestCase {

    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("vervain-large-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func makeFile(_ name: String, bytes: Int, daysOld: Int) throws {
        let url = root.appendingPathComponent(name)
        try Data(count: bytes).write(to: url)
        let date = Date(timeIntervalSinceNow: -Double(daysOld) * 86_400)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
    }

    func testFindsOnlyFilesThatAreBothLargeAndOld() async throws {
        try makeFile("big-old.bin", bytes: 2_000_000, daysOld: 400)
        try makeFile("big-new.bin", bytes: 2_000_000, daysOld: 1)
        try makeFile("small-old.bin", bytes: 1_000, daysOld: 400)

        let config = LargeFilesConfig(minSizeBytes: 1_000_000, minAgeDays: 180)
        let (cats, meta) = try await LargeFilesScanner().scan(config: config, roots: [root])

        XCTAssertEqual(cats.count, 1)
        XCTAssertEqual(cats.first?.items.map(\.name), ["big-old.bin"])
        XCTAssertEqual(meta.scannedCount, 1)
    }

    func testItemsAreNeverSelectedByDefault() async throws {
        try makeFile("big-old.bin", bytes: 2_000_000, daysOld: 400)
        let config = LargeFilesConfig(minSizeBytes: 1_000_000, minAgeDays: 180)
        let (cats, _) = try await LargeFilesScanner().scan(config: config, roots: [root])
        XCTAssertTrue(cats.flatMap(\.items).allSatisfy { !$0.isSelected })
    }

    func testEmptyResultYieldsNoCategories() async throws {
        let config = LargeFilesConfig(minSizeBytes: 1_000_000, minAgeDays: 0)
        let (cats, _) = try await LargeFilesScanner().scan(config: config, roots: [root])
        XCTAssertTrue(cats.isEmpty)
    }

    func testConfigFromDefaultsUsesFallbacksAndClamps() {
        let suite = UserDefaults(suiteName: "vervain-test-\(UUID().uuidString)")!
        XCTAssertEqual(LargeFilesConfig.fromDefaults(suite),
                       LargeFilesConfig(minSizeBytes: 100_000_000, minAgeDays: 180))
        suite.set(0, forKey: LargeFilesConfig.sizeKey)
        suite.set(-5, forKey: LargeFilesConfig.ageKey)
        XCTAssertEqual(LargeFilesConfig.fromDefaults(suite),
                       LargeFilesConfig(minSizeBytes: 1_000_000, minAgeDays: 0))
    }
}
