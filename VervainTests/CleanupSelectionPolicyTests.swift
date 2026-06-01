import XCTest
@testable import Vervain

/// Safety-critical: any regression here means Vervain could auto-select
/// files it shouldn't. Tests pin every branch of the policy.
final class CleanupSelectionPolicyTests: XCTestCase {

    // MARK: - Risky never default-on

    func test_risky_neverDefaultOn() {
        for confidence: CleanupConfidenceLevel in [.high, .medium, .low, .unknown] {
            XCTAssertFalse(
                CleanupSelectionPolicy.defaultSelection(
                    risk: .risky,
                    confidence: confidence,
                    reason: .recentCache),
                "Risky must never auto-select (confidence=\(confidence))"
            )
        }
    }

    // MARK: - Unknown / low confidence never default-on

    func test_unknownConfidence_neverDefaultOn() {
        for risk: CleanupRiskLevel in [.safe, .review, .risky] {
            XCTAssertFalse(
                CleanupSelectionPolicy.defaultSelection(
                    risk: risk,
                    confidence: .unknown,
                    reason: .recentCache),
                "Unknown confidence must never auto-select (risk=\(risk))"
            )
        }
    }

    func test_lowConfidence_neverDefaultOn() {
        XCTAssertFalse(
            CleanupSelectionPolicy.defaultSelection(
                risk: .safe, confidence: .low, reason: .oldCache(ageDays: 99))
        )
    }

    // MARK: - Downloads never default-on

    func test_oldDownload_neverDefaultOn() {
        // Even safe + high should be off for downloads.
        XCTAssertFalse(
            CleanupSelectionPolicy.defaultSelection(
                risk: .safe, confidence: .high, reason: .oldDownload(ageDays: 365))
        )
    }

    func test_download_neverDefaultOn() {
        XCTAssertFalse(
            CleanupSelectionPolicy.defaultSelection(
                risk: .safe, confidence: .high, reason: .download(extension: "dmg"))
        )
    }

    // MARK: - App leftovers require high confidence

    func test_appLeftover_highSafe_defaultsOn() {
        XCTAssertTrue(
            CleanupSelectionPolicy.defaultSelection(
                risk: .safe, confidence: .high,
                reason: .appLeftover(bundleID: "com.acme.foo"))
        )
    }

    func test_appLeftover_mediumConfidence_neverDefaultOn() {
        XCTAssertFalse(
            CleanupSelectionPolicy.defaultSelection(
                risk: .safe, confidence: .medium,
                reason: .appLeftover(bundleID: "com.acme.foo"))
        )
    }

    func test_appLeftover_reviewRisk_neverDefaultOn() {
        XCTAssertFalse(
            CleanupSelectionPolicy.defaultSelection(
                risk: .review, confidence: .high,
                reason: .appLeftover(bundleID: "com.acme.foo"))
        )
    }

    // MARK: - Review-risk items always require attention

    func test_reviewRisk_neverDefaultOn() {
        XCTAssertFalse(
            CleanupSelectionPolicy.defaultSelection(
                risk: .review, confidence: .high, reason: .recentCache)
        )
    }

    // MARK: - Happy paths

    func test_safeHigh_oldCache_defaultsOn() {
        XCTAssertTrue(
            CleanupSelectionPolicy.defaultSelection(
                risk: .safe, confidence: .high, reason: .oldCache(ageDays: 60))
        )
    }

    func test_safeMedium_oldLog_defaultsOn() {
        XCTAssertTrue(
            CleanupSelectionPolicy.defaultSelection(
                risk: .safe, confidence: .medium, reason: .oldLog(ageDays: 14))
        )
    }

    func test_safeHigh_trashItem_defaultsOn() {
        XCTAssertTrue(
            CleanupSelectionPolicy.defaultSelection(
                risk: .safe, confidence: .high, reason: .trashItem)
        )
    }
}
