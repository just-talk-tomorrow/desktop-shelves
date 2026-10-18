import XCTest
@testable import PacerIsland

@MainActor
final class ShelfInteractionTests: XCTestCase {
    func testManualCollapseUnpinsAndWaitsForPointerExitBeforeReopening() async {
        let model = IslandModel(demo: true, initiallyExpanded: true)
        model.holdShelf(true)
        model.collapseIsland()
        XCTAssertFalse(model.expanded)
        XCTAssertFalse(model.pinned)
        model.hover(true)
        XCTAssertFalse(model.expanded, "Hover at the just-clicked button must not reopen the island")
        model.hover(false)
        model.hover(true)
        XCTAssertTrue(model.expanded)
        model.collapseIsland()
        model.holdShelf(true)
        XCTAssertTrue(model.expanded, "Dragging files can still open the shelf after manual collapse")
        model.holdShelf(false)
        await model.shutdown()
    }

    func testHoldingDragKeepsIslandOpenUntilReleased() async {
        let model = IslandModel(demo: true)
        model.holdShelf(true)
        model.hover(false)
        model.close()
        try? await Task.sleep(for: .milliseconds(450))
        XCTAssertTrue(model.expanded, "An outside click or hover exit cannot hide a live drop target")
        model.holdShelf(false)
        try? await Task.sleep(for: .milliseconds(450))
        XCTAssertFalse(model.expanded)
        await model.shutdown()
    }

    func testOnlyNewStableScreenshotsAreCopiedAndToggleResetsBaseline() async throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("ShelfCaptureTests-" + UUID().uuidString)
        let inbox = base.appendingPathComponent("screenshots")
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let name = "ShelfCaptureTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let bytes = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=")!
        try bytes.write(to: inbox.appendingPathComponent("old.png"))
        let store = ShelfStore(rootURL: base.appendingPathComponent("shelf"))
        let capture = ShelfCapture(store: store, defaults: defaults, directory: inbox,
            systemDirectory: base.appendingPathComponent("unused"), automaticallyPoll: false)
        await capture.scan()
        XCTAssertTrue(store.items.isEmpty, "Previously captured images stay untouched")
        let fresh = inbox.appendingPathComponent("new.png")
        try Data().write(to: fresh)
        await capture.scan()
        XCTAssertTrue(store.items.isEmpty, "Do not copy a screenshot that is still being written")
        try bytes.write(to: fresh)
        await capture.scan()
        XCTAssertTrue(store.items.isEmpty)
        await capture.scan()
        XCTAssertEqual(store.items.map(\.displayName), ["new.png"])
        let item = try XCTUnwrap(store.items.first)
        XCTAssertEqual(try Data(contentsOf: store.url(for: item)), bytes)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fresh.path))
        await capture.scan()
        XCTAssertEqual(store.items.count, 1, "A screenshot enters the shelf only once")
        capture.enabled = false
        try bytes.write(to: inbox.appendingPathComponent("disabled.png"))
        await capture.scan()
        capture.enabled = true
        await capture.scan(); await capture.scan()
        XCTAssertEqual(store.items.count, 1, "Re-enabling never imports screenshots made while disabled")
    }
}
