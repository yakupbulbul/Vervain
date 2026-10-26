import XCTest
@testable import Vervain

final class PrivacyScannerTests: XCTestCase {

    private var home: URL!

    override func setUpWithError() throws {
        home = FileManager.default.temporaryDirectory
            .appendingPathComponent("vervain-privacy-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: home)
    }

    private func write(_ relative: String, bytes: Int = 4_096) throws {
        let url = home.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(count: bytes).write(to: url)
    }

    func testClassifiesRiskByKind() async throws {
        try write("Library/Caches/com.apple.Safari/a.db")
        try write("Library/Safari/History.db")
        try write("Library/Cookies/Cookies.binarycookies")

        let (cats, _) = try await PrivacyScanner().scan(home: home)
        let byKind = Dictionary(uniqueKeysWithValues: cats.map { ($0.kind, $0) })

        XCTAssertEqual(byKind[.browserCaches]?.items.first?.riskLevel, .safe)
        XCTAssertEqual(byKind[.browserHistory]?.items.first?.riskLevel, .review)
        XCTAssertEqual(byKind[.browserCookies]?.items.first?.riskLevel, .risky)
    }

    func testOnlyCachesAreSelectedByDefault() async throws {
        try write("Library/Caches/com.apple.Safari/a.db")
        try write("Library/Safari/History.db")
        try write("Library/Cookies/Cookies.binarycookies")

        let (cats, _) = try await PrivacyScanner().scan(home: home)
        let selected = cats.flatMap(\.items).filter(\.isSelected)
        XCTAssertEqual(selected.count, 1)
        XCTAssertEqual(selected.first?.riskLevel, .safe)
    }

    func testFindsChromiumProfilesAndSkipsMissingBrowsers() async throws {
        try write("Library/Application Support/Google/Chrome/Default/History")
        try write("Library/Application Support/Google/Chrome/Profile 2/Network/Cookies")

        let (cats, _) = try await PrivacyScanner().scan(home: home)
        let names = cats.flatMap(\.items).map(\.name)
        XCTAssertTrue(names.contains("Chrome – History"))
        XCTAssertTrue(names.contains("Chrome – Cookies"))
        XCTAssertFalse(names.contains { $0.hasPrefix("Firefox") })
    }

    func testEmptyHomeProducesNothing() async throws {
        let (cats, meta) = try await PrivacyScanner().scan(home: home)
        XCTAssertTrue(cats.isEmpty)
        XCTAssertEqual(meta.scannedCount, 0)
    }
}
