import AppKit
import SwiftUI
import CoreImage.CIFilterBuiltins

@MainActor
final class ShelfModel: ObservableObject {
    @Published var rackSkin: RackSkin = UserDefaults.standard.string(forKey: "rackSkin").flatMap(RackSkin.init(rawValue:)) ?? .silver {
        didSet { UserDefaults.standard.set(rackSkin.rawValue, forKey: "rackSkin") }
    }
    @Published var discStyle: DiscStyle = UserDefaults.standard.string(forKey: "discStyle").flatMap(DiscStyle.init(rawValue:)) ?? .glass {
        didSet { UserDefaults.standard.set(discStyle.rawValue, forKey: "discStyle") }
    }
    @Published private(set) var layoutSeed: UInt64 = UserDefaults.standard.string(forKey: "layoutSeed").flatMap(UInt64.init) ?? 0
    func shuffleArrangement() {
        var next = UInt64.random(in: 1...UInt64.max)
        while next == layoutSeed { next = UInt64.random(in: 1...UInt64.max) }
        layoutSeed = next; UserDefaults.standard.set(String(next), forKey: "layoutSeed")
        status = "已随机摆放 · \(displaySummary)"
    }
    func discColor(for albumID: String) -> DiscStyle {
        discStyle == .mixed ? ShelfArrangement.color(for: albumID, seed: layoutSeed) : discStyle
    }
    @Published private(set) var library = ShelfLibrary()
    @Published var page = 0
    @Published private(set) var loading = false
    @Published private(set) var syncFailed = false
    @Published var status = "连接网易云，或添加专辑链接"
    @Published var qrImage: NSImage?
    @Published var qrStatus = "用网易云音乐 App 扫码连接"
    @Published var loginBusy = false
    @Published var connected = false
    var albums: [RecordAlbum] { library.albums }
    var visibleAlbums: [RecordAlbum] {
        guard page >= 0, page < pageCount else { return [] }
        return Array(ShelfArrangement.ordered(albums, seed: layoutSeed).dropFirst(page * 9).prefix(9))
    }
    var pageCount: Int { library.pageCount }
    var displaySummary: String {
        let count = ShelfArrangement.displayItems(visibleAlbums, seed: layoutSeed).count
        return count > visibleAlbums.count ? "\(albums.count) 张专辑 · 本页 \(count) 件展示" : "\(albums.count) 张专辑"
    }
    var onConnection: (() -> Void)?
    var footerText: String { loading || syncFailed || preparingPlayback ? status : displaySummary }
    private let disk: LibraryDisk
    private let bridge: any MusicRequesting
    private let sessionStore: any SessionStoring
    private var cookie: String?
    private var qrTask: Task<Void, Never>?
    private var loginGeneration = 0
    private var diskWritable = true
    private var syncRequested = false
    private var shouldRestoreSession = false
    private func finishLoading() {
        loading = false
        if syncRequested { syncRequested = false; refresh() }
    }
    init(root: URL? = nil, resources: URL? = nil, loadSession: Bool = true, requestClient: (any MusicRequesting)? = nil, sessionStore: any SessionStoring = SecureSessionStore()) {
        disk = LibraryDisk(root: root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Metal Record Shelf"))
        bridge = requestClient ?? MusicBridge(resources: resources ?? Bundle.main.resourceURL!)
        self.sessionStore = sessionStore
        do { library = try disk.load(); if !library.albums.isEmpty { status = "\(library.albums.count) 张专辑 · 点击在网易云打开" } }
        catch { diskWritable = false; status = "本地收藏无法读取，文件已保留；请先检查存储目录。" }
        shouldRestoreSession = loadSession
        if !UserDefaults.standard.bool(forKey: "glassAppearanceV1") {
            discStyle = .glass
            UserDefaults.standard.set(true, forKey: "glassAppearanceV1")
            UserDefaults.standard.set(DiscStyle.glass.rawValue, forKey: "discStyle")
        }
    }
    func restoreSession() {
        guard shouldRestoreSession, !UserDefaults.standard.bool(forKey: "sessionManuallyDisconnected") else { return }
        shouldRestoreSession = false
        let vault = sessionStore
        Task { [weak self] in
            let saved = await Task.detached(priority: .userInitiated) { vault.load() }.value
            guard let self, self.cookie == nil else { return }
            guard let saved else {
                self.qrStatus = "请用网易云音乐手机 App 扫码连接，无需输入电脑密码。"
                return
            }
            self.cancelLogin()
            self.cookie = saved; self.connected = true
            self.qrImage = nil; self.qrStatus = "已连接网易云，授权仅保存在本机钥匙串"
            await self.sync()
        }
    }
    func showConnection() { onConnection?() }
    func refresh() { Task { await sync() } }
    func sync() async {
        guard !loading else { syncRequested = true; return }
        guard let cookie else { status = "请先扫码连接网易云，读取喜欢的音乐"; syncFailed = true; return }
        loading = true; syncFailed = false; status = "正在同步收藏与喜欢的音乐…"
        defer { finishLoading() }
        do {
            let result = try await MusicLibrarySync(bridge: bridge).fetch(cookie: cookie) { [weak self] message in
                guard let self, self.cookie == cookie, self.connected else { return }
                self.status = message
            }
            guard self.cookie == cookie, connected else { return }
            var next = library; next.cloud = result.albums
            try commit(next)
            status = albums.isEmpty ? "收藏及喜欢的音乐中暂无可展示专辑" : "同步完成 · \(albums.count) 张专辑 · 已读取 \(result.likedSongCount) 首喜欢歌曲"
            let unavailable = result.missingSongCount + result.skippedAlbumCount
            if unavailable > 0 { status += "；\(unavailable) 首无法取得专辑资料" }
        } catch {
            guard self.cookie == cookie, connected else { return }
            status = "\(error.localizedDescription) 已保留原有专辑。"; syncFailed = true
        }
    }
    func add(_ input: String) async -> Bool {
        guard !loading else { status = "正在同步，请稍后再添加"; return false }
        guard let id = ShelfLibrary.albumID(from: input) else { status = "请粘贴完整网易云专辑链接，或输入数字专辑 ID"; return false }
        guard !albums.contains(where: { $0.id == id }) else { status = "这张专辑已经在架子上了"; return false }
        loading = true; status = "正在读取专辑…"
        defer { finishLoading() }
        do {
            struct Result: Decodable { let album: RecordAlbum }
            let result = try JSONDecoder().decode(Result.self, from: await bridge.call("album", fields: ["id": id]))
            var next = library; next.hidden?.remove(result.album.id); next.manual.append(result.album)
            try commit(next); page = max(0, (ShelfArrangement.ordered(albums, seed: layoutSeed).firstIndex(where: { $0.id == id }) ?? 0) / 9)
            status = "已添加《\(result.album.title)》"
            return true
        } catch { status = error.localizedDescription; return false }
    }
    func remove(_ album: RecordAlbum) {
        var next = library
        if next.hidden == nil { next.hidden = [] }; next.hidden?.insert(album.id)
        next.manual.removeAll { $0.id == album.id }; next.cloud.removeAll { $0.id == album.id }
        do { try commit(next); status = "已从架子移出；网易云收藏不变" } catch { status = error.localizedDescription }
    }
    private func commit(_ next: ShelfLibrary) throws {
        guard diskWritable else { throw MusicFailure(message: "本地清单无法读取，暂不覆盖原文件。") }
        try disk.save(next); library = next; page = min(page, pageCount - 1)
    }
    @Published private(set) var preparingPlayback = false
    func openAlbum(_ album: RecordAlbum) {
        guard !preparingPlayback else { return }
        guard let client = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.netease.163music") else {
            status = "未找到网易云音乐客户端，请先安装客户端。"; syncFailed = true; showConnection(); return
        }
        preparingPlayback = true
        status = "正在准备《\(album.title)》的首曲…"
        Task { [weak self] in
            guard let self else { return }
            defer { self.preparingPlayback = false }
            do {
                struct Target: Decodable { let songID: String; let title: String }
                let target = try JSONDecoder().decode(Target.self, from: await bridge.call("playTarget", fields: ["id": album.id]))
                guard let link = NeteasePlaybackLink.song(target.songID) else { throw MusicFailure(message: "网易云返回的歌曲编号无效。") }
                launchPlayer(client: client, link: link, title: target.title)
            } catch {
                self.status = "\(error.localizedDescription)"; self.syncFailed = true; self.showConnection()
            }
        }
    }
    private func launchPlayer(client: URL, link: URL, title: String) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSApp.activate()
        NSApp.yieldActivation(toApplicationWithBundleIdentifier: "com.netease.163music")
        NSWorkspace.shared.openApplication(at: client, configuration: configuration) { [weak self] application, error in
            Task { @MainActor in
                guard let self else { return }
                guard error == nil, let application else {
                    self.status = "网易云客户端未能打开，请稍后重试。"; self.syncFailed = true; self.showConnection(); return
                }
                application.unhide()
                NSApp.yieldActivation(to: application)
                _ = application.activate(from: .current, options: [.activateAllWindows])
                NSWorkspace.shared.open([link], withApplicationAt: client, configuration: configuration) { [weak self] _, error in
                    Task { @MainActor in
                        guard let self else { return }
                        if error != nil { self.status = "网易云未能接收播放请求，请稍后重试。"; self.syncFailed = true; return }
                        application.unhide()
                        NSApp.yieldActivation(to: application)
                        _ = application.activate(from: .current, options: [.activateAllWindows])
                        try? await Task.sleep(for: .milliseconds(350))
                        if !application.isActive {
                            _ = application.activate(options: [.activateAllWindows])
                            try? await Task.sleep(for: .milliseconds(350))
                        }
                        self.status = application.isActive ? "网易云已在前台 · 已请求播放《\(title)》" : "播放请求已发送；网易云未能切到前台，请点 Dock 中的网易云图标。"
                        self.syncFailed = !application.isActive
                    }
                }
            }
        }
    }

    func beginLogin() {
        guard !connected else { return }
        cancelLogin(); loginGeneration += 1
        let expected = loginGeneration
        qrImage = nil; loginBusy = true; qrStatus = "正在生成网易云二维码…"
        qrTask = Task { [weak self] in
            guard let self else { return }
            defer { if expected == self.loginGeneration { self.loginBusy = false } }
            do {
                struct Key: Decodable { let key: String; let url: String }
                struct Check: Decodable { let code: Int; let message: String?; let cookie: String? }
                let key = try JSONDecoder().decode(Key.self, from: await bridge.call("qrKey"))
                guard expected == loginGeneration, !Task.isCancelled else { return }
                let filter = CIFilter.qrCodeGenerator(); filter.message = Data(key.url.utf8)
                if let image = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
                   let bitmap = CIContext().createCGImage(image, from: image.extent) { qrImage = NSImage(cgImage: bitmap, size: NSSize(width: 208, height: 208)) }
                qrStatus = "网易云音乐 App → 扫一扫；请在手机上确认授权"
                for _ in 0..<60 {
                    try await Task.sleep(for: .seconds(3))
                    guard expected == loginGeneration, !Task.isCancelled else { return }
                    let result = try JSONDecoder().decode(Check.self, from: await bridge.call("qrCheck", fields: ["key": key.key]))
                    guard expected == loginGeneration, !Task.isCancelled else { return }
                    switch result.code {
                    case 800: qrStatus = "二维码已过期，请点重新生成"; return
                    case 802: qrStatus = "已扫码，请在网易云手机 App 上确认"
                    case 803:
                        guard let value = result.cookie, !value.isEmpty else { throw MusicFailure(message: "网易云未返回有效授权，请重新扫码") }
                        cookie = value; connected = true; qrImage = nil
                        UserDefaults.standard.set(false, forKey: "sessionManuallyDisconnected")
                        qrStatus = "已连接网易云，正在同步专辑…"
                        let vault = sessionStore
                        // Keychain failure must not invalidate an otherwise
                        // successful phone authorization or block the interface.
                        Task { [weak self] in
                            let saved = await Task.detached(priority: .utility) {
                                do { try vault.save(value); return true } catch { return false }
                            }.value
                            guard let self, self.cookie == value, self.connected else { return }
                            self.qrStatus = saved ? "已连接网易云，授权仅保存在本机钥匙串" : "已连接（仅本次运行）。系统未允许保存授权，下次打开需重新扫码；无需输入电脑密码。"
                        }
                        await sync(); return
                    default: break
                    }
                }
                qrStatus = "二维码已过期，请重新生成"
            } catch is CancellationError {} catch { if expected == loginGeneration { qrStatus = error.localizedDescription } }
        }
    }
    func cancelLogin() { loginGeneration += 1; qrTask?.cancel(); qrTask = nil; loginBusy = false }
    func logout() {
        cancelLogin(); let cleared = sessionStore.clear(); cookie = nil; connected = false; qrImage = nil
        UserDefaults.standard.set(true, forKey: "sessionManuallyDisconnected")
        var next = library; next.cloud = []
        do { try commit(next); status = "已断开网易云；手动添加的专辑保留" } catch { status = error.localizedDescription }
        qrStatus = cleared ? "已断开，可以重新扫码连接" : "已断开；系统未允许清除旧授权，不会自动恢复。可以重新扫码连接。"
    }
}
