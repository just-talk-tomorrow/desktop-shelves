import XCTest
@testable import RecordShelf

private struct MemorySession: SessionStoring {
    func load() -> String? { "test-session-not-real" }
    func save(_ value: String) throws {}
    func clear() -> Bool { true }
}

private actor LibraryFixtureBridge: MusicRequesting {
    let likedCount: Int
    let failBatch: Int?
    private var batchSizes: [Int] = []
    init(likedCount: Int = 401, failBatch: Int? = nil) { self.likedCount = likedCount; self.failBatch = failBatch }
    func sizes() -> [Int] { batchSizes }
    private func album(_ id: Int) -> [String: Any] { ["id": String(id), "title": "Album \(id)", "artist": "Artist", "artwork": NSNull()] }
    func call(_ op: String, fields: [String: String]) async throws -> Data {
        let value: [String: Any]
        switch op {
        case "libraryStart":
            value = ["likedSongIDs": (0..<likedCount).map { String($0 + 1) }, "likedSongCount": likedCount, "truncated": false]
        case "subscribedPage":
            value = fields["offset"] == "0" ? ["albums": [album(900)], "nextOffset": 200, "truncated": false] : ["albums": [album(1)], "nextOffset": NSNull(), "truncated": false]
        case "likedAlbums":
            let ids = (fields["ids"] ?? "").split(separator: ",").compactMap { Int($0) }
            batchSizes.append(ids.count)
            if batchSizes.count == failBatch { throw MusicFailure(message: "测试批次连接失败") }
            let unique = Set(ids.map { ($0 - 1) % 23 + 1 }).sorted()
            value = ["albums": unique.map(album), "requestedCount": ids.count, "resolvedSongCount": ids.count, "missingSongCount": 0, "skippedAlbumCount": 0]
        default: throw MusicFailure(message: "Unexpected operation")
        }
        return try JSONSerialization.data(withJSONObject: value)
    }
}

final class MusicSyncTests: XCTestCase {
    func testHundredsOfLikesCrossAllBatchesAndMergeWithSubscribedAlbums() async throws {
        let bridge = LibraryFixtureBridge()
        let result = try await MusicLibrarySync(bridge: bridge).fetch(cookie: "fake") { _ in }
        XCTAssertEqual(result.likedSongCount, 401)
        XCTAssertEqual(result.albums.count, 24)
        XCTAssertEqual(Set(result.albums.map(\.id)).count, 24)
        XCTAssertTrue(result.albums.contains { $0.id == "900" })
        let sizes = await bridge.sizes()
        XCTAssertEqual(sizes, [200, 200, 1])
    }
    func testNoLikedSongsStillLoadsEverySubscribedPage() async throws {
        let bridge = LibraryFixtureBridge(likedCount: 0)
        let result = try await MusicLibrarySync(bridge: bridge).fetch(cookie: "fake") { _ in }
        XCTAssertEqual(result.albums.map(\.id), ["900", "1"])
        let sizes = await bridge.sizes()
        XCTAssertTrue(sizes.isEmpty)
    }
    @MainActor func testFullModelSyncPersistsRealTotalAndEnablesThreePages() async throws {
        UserDefaults.standard.set(false, forKey: "sessionManuallyDisconnected")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = ShelfModel(root: root, resources: root, requestClient: LibraryFixtureBridge(), sessionStore: MemorySession())
        model.restoreSession()
        try await waitForSync(model)
        XCTAssertFalse(model.syncFailed, model.status)
        XCTAssertEqual(model.albums.count, 24)
        XCTAssertEqual(model.pageCount, 3)
        model.page = 2
        XCTAssertEqual(model.visibleAlbums.count, 6)
        XCTAssertEqual(try LibraryDisk(root: root).load().cloud.count, 24)
        let reopened = ShelfModel(root: root, resources: root, loadSession: false)
        XCTAssertEqual(reopened.albums, model.albums)
    }
    @MainActor func testFailedSecondBatchNeverOverwritesOldLibraryWithPartialData() async throws {
        UserDefaults.standard.set(false, forKey: "sessionManuallyDisconnected")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let old = ShelfLibrary(cloud: [RecordAlbum(id: "88", title: "Old saved album", artist: "Artist", artwork: nil)])
        let disk = LibraryDisk(root: root)
        try disk.save(old)
        let model = ShelfModel(root: root, resources: root, requestClient: LibraryFixtureBridge(failBatch: 2), sessionStore: MemorySession())
        model.restoreSession()
        try await waitForSync(model)
        XCTAssertTrue(model.syncFailed)
        XCTAssertEqual(model.library, old)
        XCTAssertEqual(try disk.load(), old)
        XCTAssertTrue(model.footerText.contains("已保留"))
    }
    @MainActor private func waitForSync(_ model: ShelfModel) async throws {
        for _ in 0..<100 {
            if model.syncFailed || model.status.hasPrefix("同步完成") { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("Sync did not complete")
    }
}
