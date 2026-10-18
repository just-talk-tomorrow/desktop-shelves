import AppKit
import XCTest
@testable import PacerIsland

@MainActor
final class ShelfStoreTests: XCTestCase {
    private func temporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ShelfTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }

    func testFilesFoldersAndDuplicateNamesAreIndependentCopiesAcrossRelaunch() async throws {
        let base = try temporaryDirectory(), originals = base.appendingPathComponent("originals")
        try FileManager.default.createDirectory(at: originals, withIntermediateDirectories: true)
        let first = originals.appendingPathComponent("same.txt")
        try Data("first".utf8).write(to: first)
        let folder = originals.appendingPathComponent("folder")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let second = folder.appendingPathComponent("same.txt")
        try Data("second".utf8).write(to: second)
        let root = base.appendingPathComponent("shelf"), store = ShelfStore(rootURL: root)
        let count = await store.importURLs([first, second, folder])
        XCTAssertEqual(count, 3)
        XCTAssertNil(store.error)
        XCTAssertEqual(store.items.map(\.displayName), ["same.txt", "same.txt", "folder"])
        XCTAssertEqual(store.items.map(\.kind), [.file, .file, .folder])
        XCTAssertEqual(Set(store.items.map(\.id)).count, 3)
        XCTAssertTrue(FileManager.default.fileExists(atPath: first.path), "Import never moves originals")
        try FileManager.default.removeItem(at: originals)
        let reopened = ShelfStore(rootURL: root)
        XCTAssertEqual(reopened.items, store.items)
        XCTAssertNil(reopened.error)
        XCTAssertEqual(try String(contentsOf: reopened.url(for: reopened.items[0]), encoding: .utf8), "first")
        XCTAssertEqual(try String(contentsOf: reopened.url(for: reopened.items[1]), encoding: .utf8), "second")
        XCTAssertEqual(try String(contentsOf: reopened.url(for: reopened.items[2]).appendingPathComponent("same.txt"), encoding: .utf8), "second")
    }

    func testPaginationPreservesDropOrderAtEightNineAndSeventeen() async throws {
        let base = try temporaryDirectory(), store = ShelfStore(rootURL: base.appendingPathComponent("shelf"))
        XCTAssertEqual(store.pageCount, 1)
        XCTAssertTrue(store.items(on: 0).isEmpty)
        var inputs: [URL] = []
        for index in 0..<17 {
            let file = base.appendingPathComponent("\(index).txt")
            try Data("\(index)".utf8).write(to: file)
            inputs.append(file)
        }
        let firstCount = await store.importURLs(Array(inputs.prefix(8)))
        XCTAssertEqual(firstCount, 8)
        XCTAssertEqual(store.pageCount, 1)
        XCTAssertEqual(store.items(on: 0).count, 8)
        let ninthCount = await store.importURLs([inputs[8]])
        XCTAssertEqual(ninthCount, 1)
        XCTAssertEqual(store.pageCount, 2)
        XCTAssertEqual(store.items(on: 1).map(\.displayName), ["8.txt"])
        let restCount = await store.importURLs(Array(inputs.dropFirst(9)))
        XCTAssertEqual(restCount, 8)
        XCTAssertEqual(store.pageCount, 3)
        XCTAssertEqual(store.items(on: 2).map(\.displayName), ["16.txt"])
        XCTAssertEqual(store.items.map(\.displayName), (0..<17).map { "\($0).txt" })
        XCTAssertTrue(store.items(on: -1).isEmpty)
        XCTAssertTrue(store.items(on: Int.max).isEmpty)
    }

    func testMissingInputAndManagedFileAreVisibleWithoutDeletingRecords() async throws {
        let base = try temporaryDirectory(), root = base.appendingPathComponent("shelf")
        let source = base.appendingPathComponent("valid.txt")
        try Data("kept".utf8).write(to: source)
        let store = ShelfStore(rootURL: root)
        let count = await store.importURLs([base.appendingPathComponent("missing"), source])
        XCTAssertEqual(count, 1)
        XCTAssertNotNil(store.error)
        let item = try XCTUnwrap(store.items.first)
        try FileManager.default.removeItem(at: store.url(for: item))
        let reopened = ShelfStore(rootURL: root)
        XCTAssertEqual(reopened.items, [item])
        XCTAssertNotNil(reopened.error)
    }

    func testCorruptOrMissingManifestNeverOverwritesExistingData() async throws {
        let base = try temporaryDirectory(), root = base.appendingPathComponent("shelf")
        let store = ShelfStore(rootURL: root)
        let initialCount = await store.importText("existing content")
        XCTAssertEqual(initialCount, 1)
        let managed = try XCTUnwrap(store.items.first).id
        let manifest = root.appendingPathComponent("manifest.json"), corrupt = Data("not valid JSON".utf8)
        try corrupt.write(to: manifest)
        let reopened = ShelfStore(rootURL: root)
        XCTAssertNotNil(reopened.error)
        let blockedCount = await reopened.importText("new content")
        XCTAssertEqual(blockedCount, 0)
        XCTAssertEqual(try Data(contentsOf: manifest), corrupt)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("Items/\(managed.uuidString)").path))
        try FileManager.default.removeItem(at: manifest)
        let missingManifest = ShelfStore(rootURL: root)
        XCTAssertNotNil(missingManifest.error)
        let missingCount = await missingManifest.importText("cannot silently reset")
        XCTAssertEqual(missingCount, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: manifest.path))
    }

    func testFailedManifestCommitRollsBackNewCopiesAndKeepsExistingRecords() async throws {
        let base = try temporaryDirectory(), root = base.appendingPathComponent("shelf")
        let store = ShelfStore(rootURL: root)
        _ = await store.importText("existing")
        let previous = store.items
        let manifest = root.appendingPathComponent("manifest.json")
        let originalManifest = try Data(contentsOf: manifest)
        try FileManager.default.removeItem(at: manifest)
        try FileManager.default.createDirectory(at: manifest, withIntermediateDirectories: false)
        let count = await store.importText("must roll back")
        XCTAssertEqual(count, 0)
        XCTAssertEqual(store.items, previous)
        XCTAssertNotNil(store.error)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("Items").path), previous.map { $0.id.uuidString })
        // Restore the pre-existing manifest, simulating removal of a temporary external obstruction.
        try FileManager.default.removeItem(at: manifest)
        try originalManifest.write(to: manifest)
        XCTAssertEqual(ShelfStore(rootURL: root).items, previous)
    }

    func testTextLinksImagesAndSymlinksKeepManagedContentOnly() async throws {
        let base = try temporaryDirectory(), store = ShelfStore(rootURL: base.appendingPathComponent("shelf"))
        let textCount = await store.importText("a note\nsecond line")
        let linkCount = await store.importText("https://example.com/resource")
        let image = NSImage(size: NSSize(width: 2, height: 2))
        image.lockFocus(); NSColor.red.setFill(); NSBezierPath(rect: NSRect(x: 0, y: 0, width: 2, height: 2)).fill(); image.unlockFocus()
        let imageCount = await store.importImage(image)
        XCTAssertEqual(textCount + linkCount + imageCount, 3)
        XCTAssertEqual(store.items.map(\.kind), [.text, .link, .image])
        XCTAssertEqual(try String(contentsOf: store.url(for: store.items[0]), encoding: .utf8), "a note\nsecond line")
        XCTAssertNotNil(NSImage(contentsOf: store.url(for: store.items[2])))
        let original = base.appendingPathComponent("source.txt"), symlink = base.appendingPathComponent("reference.txt")
        try Data("source".utf8).write(to: original)
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: original)
        let symlinkCount = await store.importURLs([symlink])
        XCTAssertEqual(symlinkCount, 0)
        XCTAssertNotNil(store.error)
        XCTAssertEqual(store.items.count, 3)
        XCTAssertEqual(try String(contentsOf: original, encoding: .utf8), "source")
    }
}
