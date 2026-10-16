import XCTest
@testable import RecordShelf

final class LibraryTests: XCTestCase {
    private func album(_ id: Int) -> RecordAlbum { RecordAlbum(id: String(id), title: "Album \(id)", artist: "Artist", artwork: URL(string: "https://example.com/\(id).jpg")) }
    func testOnlyValidOfficialAlbumLinksAreAccepted() {
        for text in ["32311", "https://music.163.com/#/album?id=32311", "https://music.163.com/album?id=32311&userid=42", "https://y.music.163.com/m/album?id=32311"] {
            XCTAssertEqual(ShelfLibrary.albumID(from: text), "32311", text)
        }
        for text in ["", "0", "００１", "https://evil.example/album?id=32311", "https://music.163.com/song?id=32311", "file:///album?id=32311", "123;open something"] {
            XCTAssertNil(ShelfLibrary.albumID(from: text), text)
        }
    }
    func testNineTenNineteenAndDuplicateCloudAlbumsKeepOrder() {
        var state = ShelfLibrary(manual: (1...9).map(album), cloud: [album(1)])
        XCTAssertEqual(state.pageCount, 1); XCTAssertEqual(state.items(on: 0).count, 9)
        state.cloud.append(album(10))
        XCTAssertEqual(state.pageCount, 2); XCTAssertEqual(state.items(on: 1).map(\.id), ["10"])
        state.cloud += (11...19).map(album)
        XCTAssertEqual(state.pageCount, 3); XCTAssertEqual(state.items(on: 2).map(\.id), ["19"])
        XCTAssertEqual(state.albums.map(\.id), (1...19).map(String.init))
        XCTAssertTrue(state.items(on: -1).isEmpty); XCTAssertTrue(state.items(on: Int.max).isEmpty)
    }
    func testAtomicPersistenceAndCorruptFilePreservation() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("RecordShelfTests-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let disk = LibraryDisk(root: root)
        XCTAssertTrue(try disk.load().albums.isEmpty)
        let state = ShelfLibrary(manual: [album(1)], cloud: [album(2)])
        try disk.save(state)
        XCTAssertEqual(try disk.load(), state)
        let damaged = Data("corrupt".utf8)
        try damaged.write(to: disk.file)
        XCTAssertThrowsError(try disk.load())
        XCTAssertEqual(try Data(contentsOf: disk.file), damaged)
    }
    func testShuffleAndPresentationAreStableCompleteAndAsymmetric() {
        let albums = (1...23).map(album)
        let first = ShelfArrangement.ordered(albums, seed: 1234)
        XCTAssertEqual(first, ShelfArrangement.ordered(albums, seed: 1234))
        XCTAssertEqual(Set(first.map(\.id)), Set(albums.map(\.id)))
        XCTAssertEqual(first.count, albums.count)
        XCTAssertNotEqual(first, ShelfArrangement.ordered(albums, seed: 4321))
        let styles = first.enumerated().map { ShelfArrangement.style(for: $0.element.id, seed: 1234, index: $0.offset) }
        XCTAssertTrue(styles.contains { $0.isDisc }); XCTAssertTrue(styles.contains { !$0.isDisc })
        XCTAssertGreaterThan(Set(styles.map(\.size)).count, 1)
        XCTAssertTrue(styles.allSatisfy { (76...88).contains($0.size) && (-4...4).contains($0.xOffset) })
        XCTAssertGreaterThan(Set(albums.map { ShelfArrangement.color(for: $0.id, seed: 1234) }).count, 1)
    }
    func testOldLibraryLoadsAndLocallyHiddenAlbumsStayHiddenAfterRefresh() throws {
        let old = Data(#"{"manual":[],"cloud":[],"nickname":null}"#.utf8)
        XCTAssertTrue(try JSONDecoder().decode(ShelfLibrary.self, from: old).albums.isEmpty)
        var library = ShelfLibrary(manual: [album(1)], cloud: [album(2)])
        library.hidden = ["2"]
        library.cloud = [album(2), album(3)]
        XCTAssertEqual(library.albums.map(\.id), ["1", "3"])
    }
    func testRandomRowsPreserveEveryAlbumWithoutEmptySlots() {
        for count in 0...9 {
            let albums = (0..<count).map(album)
            for seed: UInt64 in 0..<20 {
                let rows = ShelfArrangement.rows(albums, seed: seed)
                XCTAssertEqual(rows.count, 3)
                XCTAssertTrue(rows.allSatisfy { $0.count <= 3 })
                XCTAssertEqual(rows.flatMap { $0 }, albums)
                XCTAssertEqual(rows, ShelfArrangement.rows(albums, seed: seed))
            }
        }
        let eight = (1...8).map(album)
        XCTAssertGreaterThan(Set((0..<20).map { seed in ShelfArrangement.rows(eight, seed: UInt64(seed)).map { String($0.count) }.joined() }).count, 1)
    }
    func testEightAlbumsHaveNineHonestDisplayItemsAndNineHaveNoCompanion() {
        for count in 0...9 {
            let albums = (0..<count).map(album)
            let items = ShelfArrangement.displayItems(albums, seed: 123)
            XCTAssertEqual(items.count, count == 8 ? 9 : count)
            XCTAssertEqual(items.filter { !$0.isCompanion }.map(\.album), albums)
            XCTAssertEqual(Set(items.map(\.id)).count, items.count)
            XCTAssertEqual(items.filter(\.isCompanion).count, count == 8 ? 1 : 0)
            XCTAssertTrue(items.allSatisfy { albums.contains($0.album) })
            XCTAssertEqual(items, ShelfArrangement.displayItems(albums, seed: 123))
        }
        let styles = (0..<9).map { ShelfArrangement.style(for: String($0), seed: 123, index: $0) }
        XCTAssertGreaterThanOrEqual(styles.filter(\.isDisc).count, 3)
    }
    @MainActor func testInvalidAdditionDoesNotEraseExistingLibrary() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("RecordShelfTests-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let disk = LibraryDisk(root: root)
        try disk.save(ShelfLibrary(manual: [album(1)]))
        let model = ShelfModel(root: root, resources: root, loadSession: false)
        let result = await model.add("https://evil.example/album?id=32")
        XCTAssertFalse(result); XCTAssertEqual(model.albums.map(\.id), ["1"])
        let duplicate = await model.add("1")
        XCTAssertFalse(duplicate); XCTAssertEqual(model.albums.count, 1)
    }
    @MainActor func testLivePublicAlbumThroughNativeBridgeAndRelaunch() async throws {
        guard ProcessInfo.processInfo.environment["RECORD_SHELF_LIVE_TEST"] == "1" else { throw XCTSkip("Requires explicit live network validation") }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("RecordShelfLive-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let model = ShelfModel(root: root, resources: project, loadSession: false)
        let added = await model.add("34720827")
        XCTAssertTrue(added, model.status)
        let first = try XCTUnwrap(model.albums.first)
        XCTAssertEqual(first.id, "34720827"); XCTAssertFalse(first.title.isEmpty); XCTAssertEqual(first.artwork?.scheme, "https")
        let reopened = ShelfModel(root: root, resources: project, loadSession: false)
        XCTAssertEqual(reopened.albums, model.albums)
    }
}
