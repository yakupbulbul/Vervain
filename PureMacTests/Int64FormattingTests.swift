import XCTest
@testable import PureMac

final class Int64FormattingTests: XCTestCase {

    func test_formattedBytes_zero() {
        XCTAssertEqual(Int64(0).formattedBytes, "Zero KB")
    }

    func test_formattedBytes_kilobytes() {
        let s = Int64(1_500).formattedBytes
        // Locale-formatted; just ensure it mentions KB.
        XCTAssertTrue(s.contains("KB"), "Got \(s)")
    }

    func test_formattedBytes_megabytes() {
        let s = Int64(5_000_000).formattedBytes
        XCTAssertTrue(s.contains("MB"), "Got \(s)")
    }

    func test_formattedBytes_gigabytes() {
        let s = Int64(7_000_000_000).formattedBytes
        XCTAssertTrue(s.contains("GB"), "Got \(s)")
    }

    func test_compactBytes_excludesActualByteCount() {
        let s = Int64(7_000_000_000).compactBytes
        // Compact form should not include parenthesized actual bytes.
        XCTAssertFalse(s.contains("("), "Got \(s)")
        XCTAssertTrue(s.contains("GB"))
    }
}
