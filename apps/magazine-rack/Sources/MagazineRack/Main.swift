import AppKit
import SwiftUI
import UniformTypeIdentifiers

private final class RackPanel: NSWindow {
    var routeMouseDown:((NSEvent)->Bool)?
    override func accessibilityRole()->NSAccessibility.Role? {.window}
    override func accessibilitySubrole()->NSAccessibility.Subrole? {.standardWindow}
    override var canBecomeKey:Bool {true}
    override var canBecomeMain:Bool {false}
    override func sendEvent(_ event:NSEvent){
        if event.type == .leftMouseDown,routeMouseDown?(event) == true {return}
        super.sendEvent(event)
    }
}
private final class RackHost: NSHostingView<RackView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
@main enum MagazineRackMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.appearance=NSAppearance(named:.aqua)
        if NSRunningApplication.runningApplications(withBundleIdentifier:"cn.local.MagazineRack").contains(where:{$0.processIdentifier != getpid()}) {
            DistributedNotificationCenter.default().postNotificationName(.init("cn.local.MagazineRack.show"),object:nil,userInfo:nil,deliverImmediately:true)
            return
        }
        let delegate = RackDelegate(); app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
@MainActor final class RackDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let store = MagazineStore()
    private var panel: RackPanel!
    private var status: NSStatusItem!
    private var observer: NSObjectProtocol?
    private var preview: NSWindow?
    private var screenObserver:NSObjectProtocol?
    private var currentTheme:RackTheme {RackTheme(rawValue:UserDefaults.standard.string(forKey:"rackTheme") ?? "oak") ?? .oak}
    private var rackHeight:CGFloat {width/currentTheme.aspect}
    private var width: CGFloat { let w = UserDefaults.standard.double(forKey:"rackWidth"); return w >= 344 && w <= 680 ? w : 344 }
    func applicationDidFinishLaunching(_ notification: Notification) {
        let alignOnLaunch = !UserDefaults.standard.bool(forKey:"systemWidgetGridV1")
        if alignOnLaunch { UserDefaults.standard.set(Double(RackGeometry.standard),forKey:"rackWidth");UserDefaults.standard.set(true,forKey:"systemWidgetGridV1") }
        panel = RackPanel(contentRect:.init(x:0,y:0,width:width+88,height:rackHeight+88),styleMask:[.borderless],backing:.buffered,defer:false)
        panel.title="杂志架"; panel.isOpaque=false; panel.backgroundColor = .clear; panel.hasShadow=false
        panel.level = .init(rawValue:Int(CGWindowLevelForKey(.normalWindow))-1)
        panel.collectionBehavior=[.canJoinAllSpaces,.stationary,.ignoresCycle]
        panel.hidesOnDeactivate=false; panel.isReleasedWhenClosed=false; panel.isMovableByWindowBackground=false;panel.ignoresMouseEvents=false;panel.acceptsMouseMovedEvents=true; panel.isMovable=true
        panel.contentView = RackHost(rootView: RackView(store:store,importImages:importImages,showPreview:showPreview,export:export,alignToGrid:alignToWidgets,themeChanged:refreshThemeGeometry))
        panel.delegate=self
        panel.routeMouseDown={ [weak self] event in self?.routeArtworkControl(event) ?? false }
        if !UserDefaults.standard.bool(forKey:"wideShadowInsetsV1") {
            if let old=UserDefaults.standard.string(forKey:"rackFrame").map(NSRectFromString),old.width>0 {
                let migrated=NSRect(x:old.minX-32,y:old.minY-32,width:width+88,height:rackHeight+88)
                UserDefaults.standard.set(NSStringFromRect(migrated),forKey:"rackFrame")
            }
            UserDefaults.standard.set(true,forKey:"wideShadowInsetsV1")
        }
        if alignOnLaunch { alignToWidgets() } else { place() }; panel.orderFrontRegardless(); setupMenu()
        screenObserver=NotificationCenter.default.addObserver(forName:NSApplication.didChangeScreenParametersNotification,object:nil,queue:.main){[weak self] _ in Task { @MainActor in self?.place() }}
        observer=DistributedNotificationCenter.default().addObserver(forName:.init("cn.local.MagazineRack.show"),object:nil,queue:.main) { [weak self] _ in Task { @MainActor in self?.panel.orderFrontRegardless() } }
    }
    /// Handle the artwork controls before SwiftUI background or drag hit testing.
    /// NSEvent locations are bottom-up window coordinates; artwork is top-down.
    private func routeArtworkControl(_ event:NSEvent)->Bool {
        guard currentTheme.isGenerated,let content=panel.contentView else{return false}
        let point=CGPoint(x:event.locationInWindow.x-44,y:content.bounds.height-event.locationInWindow.y-44)
        let traceURL=URL(fileURLWithPath:"/private/tmp/magazine-rack-input.log")
        let hit=GeneratedRackMetrics.controlIndex(at:point,width:width,theme:currentTheme)
        let entry="\(Date().timeIntervalSince1970) own-window mouseDown x=\(Int(point.x)) y=\(Int(point.y)) control=\(hit.map(String.init) ?? "none")\n"
        var trace=(try? Data(contentsOf:traceURL)) ?? Data()
        if trace.count>8192 {trace=Data()};trace.append(Data(entry.utf8));try? trace.write(to:traceURL,options:.atomic)
        guard let index=GeneratedRackMetrics.controlIndex(at:point,width:width,theme:currentTheme) else{return false}
        panel.makeKey()
        if index == 2 {importImages();return true}
        if index == 3 {store.shuffleTemplates();return true}
        let menu=NSMenu()
        if index == 0 {
            for choice in RackTheme.allCases {
                menu.addItem(RackMenuItem(choice.title,selected:choice == currentTheme){[weak self] in
                    UserDefaults.standard.set(choice.rawValue,forKey:"rackTheme")
                    self?.refreshThemeGeometry()
                })
            }
            menu.addItem(.separator());menu.addItem(RackMenuItem("对齐两排系统组件",action:alignToWidgets))
        } else {
            for style in CoverStyle.mainChoices {
                menu.addItem(RackMenuItem(style.title,selected:style == store.style){[weak self] in self?.store.setStyle(style)})
            }
            let effects=NSMenu(),parent=NSMenuItem(title:"指定印刷效果",action:nil,keyEquivalent:"")
            for style in CoverStyle.effectChoices {
                effects.addItem(RackMenuItem(style.title,selected:style == store.style){[weak self] in self?.store.setStyle(style)})
            }
            parent.submenu=effects;menu.addItem(.separator());menu.addItem(parent)
        }
        let anchor=content.convert(event.locationInWindow,from:nil)
        menu.popUp(positioning:nil,at:anchor,in:content)
        return true
    }
    func windowDidMove(_ notification:Notification) { if notification.object as? NSWindow === panel { UserDefaults.standard.set(NSStringFromRect(panel.frame),forKey:"rackFrame") } }
    private func place() {
        let saved=UserDefaults.standard.string(forKey:"rackFrame").map(NSRectFromString)
        let screen=saved.flatMap{frame in NSScreen.screens.first(where:{$0.visibleFrame.intersects(RackGeometry.visibleFrame(in:frame))})} ?? NSScreen.main
        guard let screen else{return}
        let frame=saved.map{RackGeometry.fittedFrame($0,in:screen.visibleFrame,width:width,height:rackHeight)} ?? RackGeometry.alignedFrame(in:screen.visibleFrame,height:rackHeight,width:width)
        panel.setFrame(frame,display:true)
        UserDefaults.standard.set(NSStringFromRect(frame),forKey:"rackFrame")
    }
    private func refreshThemeGeometry(){
        guard let panel,let screen=panel.screen ?? NSScreen.main else{return}
        let frame=RackGeometry.fittedFrame(panel.frame,in:screen.visibleFrame,width:width,height:rackHeight)
        panel.setFrame(frame,display:true)
        UserDefaults.standard.set(NSStringFromRect(frame),forKey:"rackFrame")
    }
    @objc private func alignToWidgets() {
        guard let screen=panel.screen ?? NSScreen.main else{return}
        UserDefaults.standard.set(Double(RackGeometry.standard*currentTheme.aspect),forKey:"rackWidth")
        let frame=RackGeometry.alignedFrame(in:screen.visibleFrame,height:rackHeight,width:width)
        panel.setFrame(frame,display:true)
        UserDefaults.standard.set(NSStringFromRect(frame),forKey:"rackFrame")
    }
    private func setupMenu() {
        status=NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
        status.button?.image=NSImage(systemSymbolName:"books.vertical",accessibilityDescription:"杂志架"); status.button?.toolTip="杂志架"
        let menu=NSMenu()
        for (title,action) in [("显示 / 隐藏杂志架",#selector(toggle)),("导入图片…",#selector(importImages)),("随机更换封面",#selector(shuffle)),("对齐两排系统组件",#selector(alignToWidgets)),("放大 · 440 × 440",#selector(normal)),("更大 · 520 × 520",#selector(large)),("重置位置",#selector(reset)),("退出杂志架",#selector(quit))] {
            let item=NSMenuItem(title:title,action:action,keyEquivalent:""); item.target=self; menu.addItem(item)
        }; status.menu=menu
        let main=NSMenu(), item=NSMenuItem(), appMenu=NSMenu()
        let q=NSMenuItem(title:"退出杂志架",action:#selector(quit),keyEquivalent:"q");q.target=self;appMenu.addItem(q);item.submenu=appMenu;main.addItem(item);NSApp.mainMenu=main
    }
    @objc func importImages() {
        let picker=NSOpenPanel();picker.title="选择图片 · 自动制作杂志封面";picker.allowedContentTypes=[.image];picker.allowsMultipleSelection=true;picker.canChooseDirectories=false
        NSApp.activate(ignoringOtherApps:true)
        picker.begin { [weak self] result in if result == .OK { Task { @MainActor in self?.store.importURLs(picker.urls) } } }
    }
    func showPreview(_ item:MagazineItem) {
        guard let image=PhotoImageCache.image(at:store.imageURL(item)) else{return}
        let w=NSWindow(contentRect:.init(x:0,y:0,width:360,height:550),styleMask:[.titled,.closable],backing:.buffered,defer:false)
        w.title=item.originalName;w.isReleasedWhenClosed=false
        w.contentView=NSHostingView(rootView:VStack(spacing:12){MagazineCover(image:image,template:item.template,seed:item.seed).frame(width:330,height:462);Button("导出封面…"){self.export(item)}.padding(.bottom,10)}.padding(12).background(Color.white))
        w.center();w.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true);preview=w
    }
    func export(_ item:MagazineItem) {
        guard let image=PhotoImageCache.image(at:store.imageURL(item)) else{return}
        let picker=NSSavePanel();picker.allowedContentTypes=[.png];picker.nameFieldStringValue="OFFDAY-\(URL(fileURLWithPath:item.originalName).deletingPathExtension().lastPathComponent).png"
        NSApp.activate(ignoringOtherApps:true)
        picker.begin { [weak self] result in
            guard result == .OK,let url=picker.url else{return}
            Task { @MainActor in
                let renderer=ImageRenderer(content:MagazineCover(image:image,template:item.template,seed:item.seed).frame(width:900,height:1260));renderer.scale=2
                if let cg=renderer.cgImage,let data=NSBitmapImageRep(cgImage:cg).representation(using:.png,properties:[:]) {
                    do {try data.write(to:url,options:.atomic);self?.store.message="封面已导出"}catch{self?.store.message="导出失败，请换一个保存位置"}
                } else {self?.store.message="封面生成失败，请重试"}
            }
        }
    }
    @objc private func toggle(){if panel.isVisible{panel.orderOut(nil)}else{panel.orderFrontRegardless()}}
    @objc private func shuffle(){store.shuffleTemplates()}
    private func resize(_ value:CGFloat){
        UserDefaults.standard.set(value,forKey:"rackWidth")
        guard let screen=panel.screen ?? NSScreen.main else{return}
        let frame=RackGeometry.fittedFrame(panel.frame,in:screen.visibleFrame,width:value,height:rackHeight)
        panel.setFrame(frame,display:true)
        UserDefaults.standard.set(NSStringFromRect(frame),forKey:"rackFrame")
    }
    @objc private func normal(){resize(440)}
    @objc private func large(){resize(520)}
    @objc private func reset(){alignToWidgets()}
    @objc private func quit(){NSApp.terminate(nil)}
}
