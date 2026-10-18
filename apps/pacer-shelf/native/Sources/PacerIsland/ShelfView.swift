import AppKit
import SwiftUI
import UniformTypeIdentifiers
import QuickLookThumbnailing

/// A single, flat drawer. Stored URLs always identify the shelf's own copies.
struct ShelfView: View {
    @ObservedObject var store: ShelfStore
    @ObservedObject var model: IslandModel
    @State private var page = 0
    @State private var selected: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("暂存").font(.system(size: 12, weight: .semibold))
                Text("\(store.items.count)").foregroundStyle(PacerPalette.tertiary)
                Spacer()
                if store.importing { ProgressView().controlSize(.mini) }
                Button { model.captureShelfScreenshot() } label: { Image(systemName: "camera.viewfinder") }.help("框选截图，自动存入暂存")
                Button { paste() } label: { Image(systemName: "doc.on.clipboard") }.help("存入剪贴板内容").keyboardShortcut("v", modifiers: .command)
                Button { choose() } label: { Image(systemName: "plus") }.help("添加文件或文件夹")
                Button { page = max(0, page - 1) } label: { Image(systemName: "chevron.left") }.disabled(page == 0)
                Text("\(page + 1)/\(store.pageCount)").monospacedDigit().foregroundStyle(PacerPalette.secondary)
                Button { page = min(store.pageCount - 1, page + 1) } label: { Image(systemName: "chevron.right") }.disabled(page + 1 >= store.pageCount)
            }.font(.system(size: 11)).buttonStyle(.plain)
            if store.items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down").font(.system(size: 23, weight: .light))
                    Text("拖入文件、文件夹或图片").font(.system(size: 12))
                    Text("每页 8 个 · 拖出即复制").font(.system(size: 10)).foregroundStyle(PacerPalette.tertiary)
                }.foregroundStyle(PacerPalette.secondary)
                .frame(maxWidth: .infinity).frame(height: 168)
                .background(PacerPalette.fill, in: RoundedRectangle(cornerRadius: 9))
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                    ForEach(store.items(on: page)) { item in
                        ShelfDragCard(item: item, url: store.url(for: item), selected: selected == item.id,
                            select: { selected = item.id }, hold: { model.holdShelf($0) })
                            .frame(height: 81)
                            .contextMenu {
                                Button("在访达中显示") { NSWorkspace.shared.activateFileViewerSelecting([store.url(for: item)]) }
                                Button("移出暂存") { Task { await store.remove(item) } }
                            }
                    }
                    ForEach(0..<max(0, 8 - store.items(on: page).count), id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 8).fill(PacerPalette.fill.opacity(0.5)).frame(height: 81)
                    }
                }
            }
            HStack {
                Text(store.importing ? "正在保存副本…" : "拖入暂存 · 拖出复制").foregroundStyle(PacerPalette.tertiary)
                Spacer()
                if let item = store.items.first(where: { $0.id == selected }) {
                    Button("显示") { NSWorkspace.shared.activateFileViewerSelecting([store.url(for: item)]) }
                    Button("移除") { Task { await store.remove(item); selected = nil } }
                }
            }.font(.system(size: 10)).buttonStyle(.plain)
            ShelfCaptureToggle(capture: model.shelfCapture)
            if let error = store.error {
                Text(error).font(.system(size: 10)).foregroundStyle(PacerPalette.attention).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, IslandMetrics.rowInset)
        .onChange(of: store.items.count) { _, _ in page = min(page, store.pageCount - 1) }
    }

    private func choose() {
        model.holdShelf(true)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = true; panel.allowsMultipleSelection = true
        panel.prompt = "存入暂存"
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.begin { result in
            Task { @MainActor in
                if result == .OK { await store.importURLs(panel.urls) }
                model.holdShelf(false)
            }
        }
    }

    private func paste() {
        let board = NSPasteboard.general
        model.holdShelf(true)
        Task { @MainActor in
            if let urls = board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
                await store.importURLs(urls)
            } else if let image = NSImage(pasteboard: board) {
                await store.importImage(image)
            } else if let text = board.string(forType: .string) {
                await store.importText(text)
            } else { store.error = "剪贴板中没有可暂存的文件、图片或文字。" }
            model.holdShelf(false)
        }
    }
}

/// AppKit specifies a copy-only drag, including when the destination is Finder.
private struct ShelfDragCard: NSViewRepresentable {
    let item: ShelfItem
    let url: URL
    let selected: Bool
    let select: () -> Void
    let hold: (Bool) -> Void
    func makeNSView(context: Context) -> Card { Card() }
    func updateNSView(_ card: Card, context: Context) {
        card.configure(item: item, url: url, selected: selected, select: select, hold: hold)
    }

    final class Card: NSView, NSDraggingSource {
        private var fileURL: URL?
        private var title = ""
        private var icon: NSImage?
        private var selected = false
        private var origin: NSPoint = .zero
        private var select: (() -> Void)?
        private var hold: ((Bool) -> Void)?
        override var isFlipped: Bool { true }
        func configure(item: ShelfItem, url: URL, selected: Bool, select: @escaping () -> Void, hold: @escaping (Bool) -> Void) {
            if fileURL != url {
                icon = NSWorkspace.shared.icon(forFile: url.path)
                fileURL = url
                let request = QLThumbnailGenerator.Request(fileAt: url, size: NSSize(width: 48, height: 48),
                    scale: 2, representationTypes: .thumbnail)
                QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] representation, _ in
                    guard let image = representation?.nsImage else { return }
                    DispatchQueue.main.async {
                        guard let self, self.fileURL == url else { return }
                        self.icon = image; self.needsDisplay = true
                    }
                }
            }
            title = item.displayName; self.selected = selected; self.select = select; self.hold = hold
            setAccessibilityElement(true); setAccessibilityRole(.button); setAccessibilityLabel(title)
            setAccessibilityHelp("拖出复制文件；点击后可显示或移除")
            needsDisplay = true
        }
        override func draw(_ dirtyRect: NSRect) {
            let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
            let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
            NSColor.white.withAlphaComponent(selected ? 0.10 : 0.045).setFill(); path.fill()
            if selected { NSColor.systemTeal.withAlphaComponent(0.8).setStroke(); path.lineWidth = 1; path.stroke() }
            icon?.draw(in: NSRect(x: (bounds.width - 33) / 2, y: 8, width: 33, height: 33), from: .zero,
                       operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center; paragraph.lineBreakMode = .byTruncatingMiddle
            (title as NSString).draw(in: NSRect(x: 4, y: 48, width: bounds.width - 8, height: 28), withAttributes: [
                .font: NSFont.systemFont(ofSize: 10), .foregroundColor: NSColor(white: 0.88, alpha: 1), .paragraphStyle: paragraph])
        }
        override func mouseDown(with event: NSEvent) { origin = convert(event.locationInWindow, from: nil); select?() }
        override func mouseDragged(with event: NSEvent) {
            let point = convert(event.locationInWindow, from: nil)
            guard hypot(point.x - origin.x, point.y - origin.y) >= 4, let url = fileURL else { return }
            guard FileManager.default.fileExists(atPath: url.path) else { NSSound.beep(); return }
            hold?(true)
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            item.setDraggingFrame(NSRect(x: origin.x - 18, y: origin.y - 18, width: 36, height: 36), contents: icon)
            beginDraggingSession(with: [item], event: event, source: self).animatesToStartingPositionsOnCancelOrFail = true
        }
        func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
        func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) { hold?(false) }
        override func accessibilityPerformPress() -> Bool { select?(); return true }
    }
}

private struct ShelfCaptureToggle: View {
    @ObservedObject var capture: ShelfCapture
    var body: some View {
        Toggle("自动收纳新截图", isOn: $capture.enabled)
            .toggleStyle(.switch).controlSize(.mini).font(.system(size: 10))
            .foregroundStyle(PacerPalette.secondary)
    }
}
