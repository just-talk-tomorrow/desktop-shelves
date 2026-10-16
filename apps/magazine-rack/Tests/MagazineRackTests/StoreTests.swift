import AppKit
import XCTest
@testable import MagazineRack

final class StoreTests: XCTestCase {
    @MainActor
    func testImportDeduplicatesAndRestores() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try makeImage(in: root, name: "source.png", color: .red)
        let store = MagazineStore(root: root.appendingPathComponent("library"))
        store.importURLs([source, source])
        XCTAssertEqual(store.items.count, 1)
        XCTAssertTrue(store.message.contains("重复"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.imageURL(store.items[0]).path))
        let restored = MagazineStore(root: root.appendingPathComponent("library"))
        XCTAssertEqual(restored.items, store.items)
        XCTAssertEqual(restored.items[0].originalName, "source.png")
    }

    @MainActor
    func testNineItemsHaveTwoPages() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MagazineStore(root: root.appendingPathComponent("library"))
        let sources = try (0..<9).map { index in
            try makeImage(in: root, name: "\(index).png", color: NSColor(calibratedRed: CGFloat(index) / 10, green: 0.2, blue: 0.3, alpha: 1))
        }
        store.importURLs(sources)
        XCTAssertEqual(store.items.count, 9)
        XCTAssertEqual(store.pages, 2)
        store.page = 0
        XCTAssertEqual(store.visibleItems.count, 8)
        let firstPage=Set(store.visibleItems.map(\.id))
        XCTAssertEqual(GeneratedRackMetrics.pages(current:0,total:store.pages),[0,1])
        store.page = 1
        XCTAssertEqual(store.visibleItems.count, 1)
        XCTAssertTrue(firstPage.isDisjoint(with:Set(store.visibleItems.map(\.id))))
        let ninth=try XCTUnwrap(store.visibleItems.first)
        store.remove(ninth)
        XCTAssertEqual(store.pages,1)
        XCTAssertEqual(store.page,0)
        XCTAssertEqual(GeneratedRackMetrics.pages(current:0,total:store.pages),[0])
        XCTAssertEqual(Set(store.visibleItems.map(\.id)),firstPage)
    }

    @MainActor
    func testPartialImportAndRemovalKeepOriginal() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try makeImage(in: root, name: "source.png", color: .blue)
        let invalid = root.appendingPathComponent("invalid.txt")
        try Data("not an image".utf8).write(to: invalid)
        let store = MagazineStore(root: root.appendingPathComponent("library"))
        store.importURLs([invalid, source])
        XCTAssertEqual(store.items.count, 1)
        XCTAssertTrue(store.message.contains("无法读取"))
        let item = try XCTUnwrap(store.items.first)
        let owned = store.imageURL(item)
        store.remove(item)
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertEqual(store.pages, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: owned.path))
        XCTAssertTrue(MagazineStore(root: root.appendingPathComponent("library")).items.isEmpty)
    }

    @MainActor
    func testShuffleChangesAndPersistsTemplates() throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try makeImage(in: root, name: "source.png", color: .green)
        let library = root.appendingPathComponent("library")
        let store = MagazineStore(root: library)
        store.importURLs([source])
        let previous = try XCTUnwrap(store.items.first)
        store.shuffleTemplates()
        let next = try XCTUnwrap(store.items.first)
        XCTAssertNotEqual(previous.template, next.template)
        XCTAssertTrue((0..<240).contains(next.template))
        XCTAssertEqual(MagazineStore(root: library).items, store.items)
    }

    @MainActor
    func testStyleChoiceAppliesToImportRerollAndRestore() throws {
        let root=temporaryDirectory();defer{try? FileManager.default.removeItem(at:root)}
        let source=try makeImage(in:root,name:"style.png",color:.orange)
        let library=root.appendingPathComponent("library")
        let store=MagazineStore(root:library)
        store.setStyle(.american);store.importURLs([source])
        XCTAssertTrue((40..<80).contains(try XCTUnwrap(store.items.first).template))
        store.setStyle(.constructivist)
        let item=try XCTUnwrap(store.items.first)
        XCTAssertTrue((80..<120).contains(item.template))
        store.reroll(item)
        XCTAssertTrue((80..<120).contains(try XCTUnwrap(store.items.first).template))
        let restored=MagazineStore(root:library)
        XCTAssertEqual(restored.style,.constructivist)
        XCTAssertEqual(restored.items,store.items)
    }

    @MainActor
    func testNewEffectStylesPersistWithinTheirOwnRanges() throws {
        let root=temporaryDirectory();defer{try? FileManager.default.removeItem(at:root)}
        let source=try makeImage(in:root,name:"effects.png",color:.systemTeal)
        let library=root.appendingPathComponent("library")
        let store=MagazineStore(root:library);store.importURLs([source])
        for style in [.printEffects,.minimal] + CoverStyle.effectChoices {
            store.setStyle(style)
            XCTAssertTrue(style.range.contains(try XCTUnwrap(store.items.first).template))
            store.reroll(try XCTUnwrap(store.items.first))
            XCTAssertTrue(style.range.contains(try XCTUnwrap(store.items.first).template))
            XCTAssertEqual(MagazineStore(root:library).style,style)
        }
    }

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @MainActor
    private func makeImage(in directory: URL, name: String, color: NSColor) throws -> URL {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 8, pixelsHigh: 8,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        for x in 0..<8 { for y in 0..<8 { bitmap.setColor(color, atX: x, y: y) } }
        let url = directory.appendingPathComponent(name)
        try bitmap.representation(using: .png, properties: [:])!.write(to: url)
        return url
    }
}
