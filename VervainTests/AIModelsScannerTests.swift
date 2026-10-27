import XCTest
@testable import Vervain

final class AIModelsScannerTests: XCTestCase {

    private var home: URL!

    override func setUpWithError() throws {
        home = FileManager.default.temporaryDirectory
            .appendingPathComponent("vervain-ai-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: home)
    }

    @discardableResult
    private func makeDir(_ path: String, bytes: Int = 12_000_000) throws -> URL {
        let url = home.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try Data(count: bytes).write(to: url.appendingPathComponent("weights.bin"))
        return url
    }

    private func scan() async throws -> [CleanupCategory] {
        try await AIModelsScanner().scan(home: home).categories
    }

    func testListsEachHuggingFaceRepositoryWithReadableName() async throws {
        try makeDir(".cache/huggingface/hub/models--meta-llama--Llama-3-8B")
        try makeDir(".cache/huggingface/hub/datasets--squad")
        try makeDir(".cache/huggingface/hub/.locks")
        let cats = try await scan()
        XCTAssertEqual(cats.count, 1)
        XCTAssertEqual(Set(cats[0].items.map(\.name)), ["meta-llama/Llama-3-8B", "squad"])
        XCTAssertEqual(cats[0].title, "Hugging Face")
    }

    func testNothingIsPreSelectedAndEverythingNeedsReview() async throws {
        try makeDir(".cache/huggingface/hub/models--a--b")
        try makeDir(".ollama/models")
        try makeDir(".cache/whisper")
        let items = try await scan().flatMap(\.items)
        XCTAssertEqual(items.count, 3)
        XCTAssertTrue(items.allSatisfy { $0.riskLevel == .review && !$0.isSelected })
        XCTAssertTrue(items.allSatisfy { $0.sourceModule == .aiModels })
    }

    func testLMStudioModelsListedAsPublisherSlashModelInBothLocations() async throws {
        try makeDir(".lmstudio/models/TheBloke/Mistral-7B")
        try makeDir(".cache/lm-studio/models/lmstudio-community/Gemma")
        let items = try await scan().flatMap(\.items)
        XCTAssertEqual(Set(items.map(\.name)), ["TheBloke/Mistral-7B", "lmstudio-community/Gemma"])
    }

    func testOllamaIsOneWholeItem() async throws {
        try makeDir(".ollama/models/blobs")
        try makeDir(".ollama/models/manifests")
        let cats = try await scan()
        XCTAssertEqual(cats.count, 1)
        XCTAssertEqual(cats[0].items.count, 1)
        XCTAssertEqual(cats[0].items[0].url.lastPathComponent, "models")
    }

    func testSmallFoldersAreSkipped() async throws {
        try makeDir(".cache/torch", bytes: 1_000)
        let cats = try await scan()
        XCTAssertTrue(cats.isEmpty)
    }

    func testSymlinkedRepositoriesAreNotFollowed() async throws {
        let target = try makeDir("elsewhere")
        let hub = home.appendingPathComponent(".cache/huggingface/hub")
        try FileManager.default.createDirectory(at: hub, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: hub.appendingPathComponent("models--x--y"), withDestinationURL: target)
        let cats = try await scan()
        XCTAssertTrue(cats.isEmpty)
    }

    func testHuggingFaceBlobsCountedOnceWhenSnapshotsAreSymlinks() async throws {
        let repo = try makeDir(".cache/huggingface/hub/models--a--b/blobs", bytes: 20_000_000)
        let snapshots = home.appendingPathComponent(".cache/huggingface/hub/models--a--b/snapshots/rev")
        try FileManager.default.createDirectory(at: snapshots, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: snapshots.appendingPathComponent("weights.bin"),
            withDestinationURL: repo.appendingPathComponent("weights.bin"))
        let item = try await scan().first!.items.first!
        XCTAssertLessThan(item.size, 25_000_000)
    }

    func testCategoriesSortedBySizeDescending() async throws {
        try makeDir(".cache/whisper", bytes: 12_000_000)
        try makeDir(".ollama/models", bytes: 40_000_000)
        let cats = try await scan()
        XCTAssertEqual(cats.map(\.title), ["Ollama", "Other AI Tools"])
    }
}
