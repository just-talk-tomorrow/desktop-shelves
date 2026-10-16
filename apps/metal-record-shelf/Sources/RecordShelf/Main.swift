import AppKit
import SwiftUI

private final class DesktopPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
private final class ShelfHostingView: NSHostingView<MetalShelfView> {
    // A desktop widget should respond to the first click even when another
    // app is active; a click must not be consumed merely to focus its host.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@main
enum RecordShelfMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        // A second launch opens the existing app's controls, never a second rack.
        let id = Bundle.main.bundleIdentifier ?? "cn.local.MetalRecordShelf"
        if let other = NSRunningApplication.runningApplications(withBundleIdentifier: id).first(where: { $0.processIdentifier != getpid() }) {
            DistributedNotificationCenter.default().postNotificationName(Notification.Name("cn.local.MetalRecordShelf.show"), object: nil, userInfo: nil, deliverImmediately: true)
            _ = other
            return
        }
        let delegate = ShelfAppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class ShelfAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var model: ShelfModel!
    private var panel: DesktopPanel!
    private var controls: NSWindow?
    private var statusItem: NSStatusItem!
    private var observer: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?
    private var locked = UserDefaults.standard.bool(forKey: "positionLocked")
    private var ready = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        model = ShelfModel()
        model.onConnection = { [weak self] in self?.showConnection() }
        panel = DesktopPanel(contentRect: NSRect(x: 0, y: 0, width: ShelfGeometry.panelWidth, height: ShelfGeometry.panelHeight),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "金属唱片架"
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = !locked
        panel.contentView = ShelfHostingView(rootView: MetalShelfView(model: model))
        panel.delegate = self
        placePanel()
        ready = true
        panel.orderFrontRegardless()
        setupMenu()
        observer = DistributedNotificationCenter.default().addObserver(forName: Notification.Name("cn.local.MetalRecordShelf.show"), object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.showConnection() } }
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.placePanel() } }
        if model.albums.isEmpty { showConnection() }
        model.restoreSession()
    }
    private func setupMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "opticaldisc", accessibilityDescription: "金属唱片架")
        statusItem.button?.toolTip = "金属唱片架"
        let menu = NSMenu()
        let actions: [(String, Selector)] = [("显示 / 隐藏唱片架", #selector(toggleShelf)), ("连接网易云 / 添加专辑…", #selector(showConnection)), ("同步收藏和喜欢的音乐", #selector(refresh)), ("与系统组件列对齐", #selector(alignToWidgets)), ("锁定 / 解锁位置", #selector(toggleLock)), ("重置架子位置", #selector(resetPosition)), ("退出金属唱片架", #selector(quit))]
        for (title, action) in actions { let item = NSMenuItem(title: title, action: action, keyEquivalent: ""); item.target = self; menu.addItem(item) }
        statusItem.menu = menu
        let main = NSMenu(), appItem = NSMenuItem(), appMenu = NSMenu()
        let quit = NSMenuItem(title: "退出金属唱片架", action: #selector(quit), keyEquivalent: "q"); quit.target = self; appMenu.addItem(quit)
        appItem.submenu = appMenu; main.addItem(appItem); NSApp.mainMenu = main
    }
    private func placePanel() {
        guard let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let saved = UserDefaults.standard.string(forKey: "shelfFrame").map(NSRectFromString)
        if !UserDefaults.standard.bool(forKey: "widgetColumnAlignmentV1") {
            let old = saved.flatMap { $0.width > 0 ? $0 : nil }
            let frame = ShelfGeometry.alignedFrame(in: screen.visibleFrame, previous: old)
            panel.setFrame(frame, display: false)
            UserDefaults.standard.set(NSStringFromRect(frame), forKey: "shelfFrame")
            UserDefaults.standard.set(true, forKey: "widgetColumnAlignmentV1")
        } else if let saved, NSScreen.screens.contains(where: { $0.visibleFrame.contains(ShelfGeometry.visibleCabinet(in: saved)) }) {
            panel.setFrame(NSRect(x: saved.minX, y: saved.maxY - ShelfGeometry.panelHeight, width: ShelfGeometry.panelWidth, height: ShelfGeometry.panelHeight), display: false)
        } else {
            panel.setFrame(ShelfGeometry.alignedFrame(in: screen.visibleFrame), display: false)
        }
    }
    func windowDidMove(_ notification: Notification) {
        if ready, notification.object as? NSWindow === panel { UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: "shelfFrame") }
    }
    @objc private func toggleShelf() { if panel.isVisible { panel.orderOut(nil) } else { panel.orderFrontRegardless() } }
    @objc func showConnection() {
        if controls == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 570, height: 535), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "金属唱片架 · 连接网易云"
            window.isReleasedWhenClosed = false; window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            window.contentView = NSHostingView(rootView: ConnectionView(model: model))
            window.delegate = self
            controls = window
            window.center()
        }
        controls?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if !model.connected && model.qrImage == nil { model.beginLogin() }
    }
    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === controls { model.cancelLogin() }
    }
    @objc private func refresh() { model.refresh() }
    @objc private func toggleLock() { locked.toggle(); panel.isMovableByWindowBackground = !locked; UserDefaults.standard.set(locked, forKey: "positionLocked") }
    @objc private func alignToWidgets() {
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let frame = ShelfGeometry.alignedFrame(in: screen.visibleFrame, previous: panel.frame)
        panel.setFrame(frame, display: true)
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: "shelfFrame")
    }
    @objc private func resetPosition() { UserDefaults.standard.removeObject(forKey: "shelfFrame"); placePanel() }
    @objc private func quit() { model.cancelLogin(); NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { model.cancelLogin() }
}
