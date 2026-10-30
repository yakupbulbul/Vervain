import XCTest
@testable import Vervain

@MainActor
final class UpdateNoticeViewModelTests: XCTestCase {

    private final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0
        var count: Int { lock.withLock { value } }
        func increment() { lock.withLock { value += 1 } }
    }

    private let releaseURL = URL(string: "https://example.com/release")!
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "UpdateNoticeViewModelTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeModel(outcome: UpdateChecker.Outcome, counter: Counter) -> UpdateNoticeViewModel {
        UpdateNoticeViewModel(defaults: defaults, currentVersion: "2.0.0") { _ in
            counter.increment()
            return outcome
        }
    }

    func test_disabledByDefault_neverContactsTheNetwork() async {
        let counter = Counter()
        let model = makeModel(outcome: .available(version: "2.1.0", url: releaseURL), counter: counter)

        await model.checkIfDue()

        XCTAssertEqual(counter.count, 0)
        XCTAssertNil(model.notice)
    }

    func test_enabled_showsNoticeForNewerVersion() async {
        defaults.set(true, forKey: UpdateCheckPolicy.enabledKey)
        let counter = Counter()
        let model = makeModel(outcome: .available(version: "2.1.0", url: releaseURL), counter: counter)

        await model.checkIfDue()

        XCTAssertEqual(model.notice, .init(version: "2.1.0", url: releaseURL))
    }

    func test_enabled_checksAtMostOncePerDay() async {
        defaults.set(true, forKey: UpdateCheckPolicy.enabledKey)
        let counter = Counter()
        let model = makeModel(outcome: .upToDate, counter: counter)
        let now = Date()

        await model.checkIfDue(now: now)
        await model.checkIfDue(now: now.addingTimeInterval(3_600))
        XCTAssertEqual(counter.count, 1)

        await model.checkIfDue(now: now.addingTimeInterval(25 * 3_600))
        XCTAssertEqual(counter.count, 2)
    }

    func test_failedCheck_isNotRetriedOnTheSameDay() async {
        defaults.set(true, forKey: UpdateCheckPolicy.enabledKey)
        let counter = Counter()
        let model = makeModel(outcome: .failed, counter: counter)
        let now = Date()

        await model.checkIfDue(now: now)
        await model.checkIfDue(now: now.addingTimeInterval(60))

        XCTAssertEqual(counter.count, 1)
        XCTAssertNil(model.notice)
    }

    func test_dismissedVersion_isNotShownAgain() async {
        defaults.set(true, forKey: UpdateCheckPolicy.enabledKey)
        let counter = Counter()
        let model = makeModel(outcome: .available(version: "2.1.0", url: releaseURL), counter: counter)
        let now = Date()

        await model.checkIfDue(now: now)
        model.dismiss()
        XCTAssertNil(model.notice)

        await model.checkIfDue(now: now.addingTimeInterval(25 * 3_600))
        XCTAssertEqual(counter.count, 2)
        XCTAssertNil(model.notice)
    }

    func test_newerVersionAfterDismissal_isShown() async {
        defaults.set(true, forKey: UpdateCheckPolicy.enabledKey)
        defaults.set("2.1.0", forKey: UpdateCheckPolicy.dismissedVersionKey)
        let counter = Counter()
        let model = makeModel(outcome: .available(version: "2.2.0", url: releaseURL), counter: counter)

        await model.checkIfDue()

        XCTAssertEqual(model.notice?.version, "2.2.0")
    }
}
