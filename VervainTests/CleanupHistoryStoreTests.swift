import XCTest
@testable import Vervain

final class CleanupHistoryStoreTests: XCTestCase {

    private var file: URL!

    override func setUpWithError() throws {
        file = FileManager.default.temporaryDirectory
            .appendingPathComponent("vervain-history-\(UUID().uuidString)/history.json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: file.deletingLastPathComponent())
    }

    private func item(_ name: String, size: Int64 = 10) -> TrashedItem {
        TrashedItem(name: name, originalPath: "/tmp/\(name)", trashPath: "/tmp/trash/\(name)", size: size, category: "C")
    }

    private func entry(_ title: String, items: [TrashedItem], daysAgo: Int = 0) -> CleanupHistoryEntry {
        CleanupHistoryEntry(id: UUID(), date: Date(timeIntervalSinceNow: -Double(daysAgo) * 86_400),
                            title: title, items: items)
    }

    func testAppendLoadRoundTripNewestFirst() async {
        let store = CleanupHistoryStore(fileURL: file)
        await store.append(entry("old", items: [item("a")], daysAgo: 5))
        await store.append(entry("new", items: [item("b", size: 30), item("c", size: 20)]))
        let loaded = await store.load()
        XCTAssertEqual(loaded.map(\.title), ["new", "old"])
        XCTAssertEqual(loaded[0].itemCount, 2)
        XCTAssertEqual(loaded[0].freedBytes, 50)
    }

    func testRemoveItemsDropsEmptyEntries() async {
        let store = CleanupHistoryStore(fileURL: file)
        let a = item("a"), b = item("b"), c = item("c")
        await store.append(entry("one", items: [a, b]))
        await store.append(entry("two", items: [c]))
        await store.removeItems([a.id, c.id])
        let loaded = await store.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].items.map(\.name), ["b"])
    }

    func testHistoryIsCappedAtMaxEntries() async {
        let store = CleanupHistoryStore(fileURL: file)
        for i in 0..<(CleanupHistoryStore.maxEntries + 5) {
            await store.append(entry("e\(i)", items: [item("f\(i)")]))
        }
        let loaded = await store.load()
        XCTAssertEqual(loaded.count, CleanupHistoryStore.maxEntries)
    }

    func testClearAndMissingFile() async {
        let store = CleanupHistoryStore(fileURL: file)
        let initial = await store.load()
        XCTAssertTrue(initial.isEmpty)
        await store.append(entry("x", items: [item("a")]))
        await store.clear()
        let afterClear = await store.load()
        XCTAssertTrue(afterClear.isEmpty)
    }
}
