import XCTest
@testable import Vervain

@MainActor
final class CleanupCoordinatorTests: XCTestCase {

    private func category(risk: CleanupRiskLevel, confidence: CleanupConfidenceLevel = .high) -> CleanupCategory {
        let item = CleanupItem(
            url: URL(fileURLWithPath: "/Users/tester/Library/Caches/x"),
            size: 10,
            category: "Test",
            reason: .recentCache,
            riskLevel: risk,
            confidenceLevel: confidence,
            sourceModule: .systemJunk
        )
        return CleanupCategory(kind: .oldCaches, title: "T", icon: "x", sourceModule: .systemJunk, items: [item])
    }

    func testStartReviewEntersReviewing() {
        let coord = CleanupCoordinator()
        coord.startReview([category(risk: .safe)])
        XCTAssertEqual(coord.state, .reviewing)
        XCTAssertTrue(coord.isReviewPresented)
    }

    func testConfirmRoutesToConfirmationWhenRiskySelected() {
        let coord = CleanupCoordinator()
        var cat = category(risk: .risky)
        cat.selectAll()
        coord.startReview([cat])
        coord.confirm()
        XCTAssertEqual(coord.state, .confirming)
    }

    func testCancelResetsState() {
        let coord = CleanupCoordinator()
        coord.startReview([category(risk: .safe)])
        coord.cancel()
        XCTAssertEqual(coord.state, .idle)
        XCTAssertTrue(coord.categories.isEmpty)
    }

    func testFinishRunsCompletionOnce() {
        let coord = CleanupCoordinator()
        var calls = 0
        coord.startReview([category(risk: .safe)]) { calls += 1 }
        coord.finish()
        coord.finish()
        XCTAssertEqual(calls, 1)
    }

    func testCancelDiscardsCompletion() {
        let coord = CleanupCoordinator()
        var calls = 0
        coord.startReview([category(risk: .safe)]) { calls += 1 }
        coord.cancel()
        XCTAssertEqual(calls, 0)
    }

    func testToggleCategorySelectsThenDeselects() {
        let coord = CleanupCoordinator()
        let cat = category(risk: .review)   // review items are not default-selected
        coord.startReview([cat])
        XCTAssertEqual(coord.totalSelectedCount, 0)
        coord.toggleCategory(cat.id)
        XCTAssertEqual(coord.totalSelectedCount, 1)
        coord.toggleCategory(cat.id)
        XCTAssertEqual(coord.totalSelectedCount, 0)
    }

    func testProtectedItemIsReportedAsFailureNotTrashed() async throws {
        let item = CleanupItem(
            url: URL(fileURLWithPath: "/System"),
            size: 1,
            category: "Test",
            reason: .custom("x"),
            riskLevel: .safe,
            confidenceLevel: .high,
            sourceModule: .systemJunk
        )
        var cat = CleanupCategory(kind: .oldCaches, title: "T", icon: "x", sourceModule: .systemJunk, items: [item])
        cat.selectAll()
        let result = try await CleanupService().execute([cat])
        XCTAssertEqual(result.successCount, 0)
        XCTAssertEqual(result.failedCount, 1)
    }
}
