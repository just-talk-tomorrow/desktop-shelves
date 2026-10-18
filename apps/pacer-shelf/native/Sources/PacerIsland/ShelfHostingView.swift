import AppKit
import SwiftUI

/// The whole nonactivating island is a native drop target, including its collapsed wings.
final class ShelfHostingView: NSHostingView<IslandView> {
    private let model: IslandModel
    init(model: IslandModel, presentation: IslandPresentation) {
        self.model = model
        super.init(rootView: IslandView(model: model, presentation: presentation))
        registerForDraggedTypes([.fileURL, .png, .tiff, .URL, .string])
    }
    @available(*, unavailable) required init(rootView: IslandView) { fatalError() }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard accepts(sender.draggingPasteboard) else { return [] }
        model.shelfDropTarget = true; model.holdShelf(true)
        return .copy
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { accepts(sender.draggingPasteboard) ? .copy : [] }
    override func draggingExited(_ sender: NSDraggingInfo?) { model.shelfDropTarget = false; model.holdShelf(false) }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { accepts(sender.draggingPasteboard) }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let board = sender.draggingPasteboard
        let urls = board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        let image = urls.isEmpty ? NSImage(pasteboard: board) : nil
        let text = urls.isEmpty && image == nil ? board.string(forType: .string) ?? board.string(forType: .URL) : nil
        guard !urls.isEmpty || image != nil || text != nil else { return false }
        model.holdShelf(true)
        Task { @MainActor in
            if !urls.isEmpty { await model.shelf.importURLs(urls) }
            else if let image { await model.shelf.importImage(image) }
            else if let text { await model.shelf.importText(text) }
            model.shelfDropTarget = false; model.holdShelf(false)
        }
        return true
    }
    private func accepts(_ board: NSPasteboard) -> Bool {
        board.availableType(from: [.fileURL, .png, .tiff, .URL, .string]) != nil
    }
}
