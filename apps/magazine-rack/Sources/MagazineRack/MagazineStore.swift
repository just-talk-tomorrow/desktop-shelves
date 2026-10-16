import AppKit
import Combine
import CryptoKit
import Foundation

struct MagazineItem: Codable, Identifiable, Equatable {
    var id: UUID
    var filename: String
    var template: Int
    var seed: Int
    var originalName: String

    init(id: UUID = UUID(), filename: String, template: Int, seed: Int, originalName: String) {
        self.id = id
        self.filename = filename
        self.template = template
        self.seed = seed
        self.originalName = originalName
    }
}

enum CoverStyle:String,CaseIterable,Codable {
    case mixed, japanese, american, constructivist, minimal, printEffects
    case riso, newspaper, xerox, folded, crumpled, pop, torn, faded
    static let mainChoices:[CoverStyle] = [.mixed,.japanese,.american,.constructivist,.minimal,.printEffects]
    static let effectChoices:[CoverStyle] = [.riso,.newspaper,.xerox,.folded,.crumpled,.pop,.torn,.faded]
    var title:String {switch self {
    case .mixed:return "全部随机混合"
    case .japanese:return "日式手账"
    case .american:return "美式复古"
    case .constructivist:return "构成主义"
    case .minimal:return "留白画报"
    case .printEffects:return "无字效果混合"
    case .riso:return "Riso 孔版印刷"
    case .newspaper:return "报纸网点"
    case .xerox:return "复印机墨粉"
    case .folded:return "折痕纸张"
    case .crumpled:return "褶皱纸张"
    case .pop:return "波普套色"
    case .torn:return "撕纸拼贴"
    case .faded:return "旧纸印相"
    }}
    var range:Range<Int> {switch self {
    case .mixed:return 0..<240
    case .japanese:return 0..<40
    case .american:return 40..<80
    case .constructivist:return 80..<120
    case .minimal:return 200..<240
    case .printEffects:return 120..<200
    case .riso:return 120..<130
    case .newspaper:return 130..<140
    case .xerox:return 140..<150
    case .folded:return 150..<160
    case .crumpled:return 160..<170
    case .pop:return 170..<180
    case .torn:return 180..<190
    case .faded:return 190..<200
    }}
}

@MainActor
final class MagazineStore: ObservableObject {
    @Published var items: [MagazineItem] = []
    @Published var page: Int = 0
    @Published private(set) var style:CoverStyle = .mixed
    @Published var message: String = "拖入图片，自动生成杂志封面"

    private let root: URL
    private let images: URL
    private let manifest: URL
    private let manager = FileManager.default

    var pages: Int { max(1, (items.count + 7) / 8) }
    var visibleItems: [MagazineItem] {
        let start = min(max(page, 0), pages - 1) * 8
        return Array(items.dropFirst(start).prefix(8))
    }

    init(root: URL? = nil) {
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("cn.local.MagazineRack", isDirectory: true)
        images = self.root.appendingPathComponent("Images", isDirectory: true)
        manifest = self.root.appendingPathComponent("manifest.json")
        if let data=try? Data(contentsOf:self.root.appendingPathComponent("style.json")),let saved=try? JSONDecoder().decode(CoverStyle.self,from:data){style=saved}
        do {
            try manager.createDirectory(at: images, withIntermediateDirectories: true)
            if manager.fileExists(atPath: manifest.path) {
                let restored = try JSONDecoder().decode([MagazineItem].self, from: Data(contentsOf: manifest))
                // Keep only owned, readable images. A damaged entry cannot escape our image directory.
                items = restored.filter { isOwnedFilename($0.filename) && NSImage(contentsOf: imageURL($0)) != nil }
                for index in items.indices {
                    items[index].template = ((items[index].template % 240) + 240) % 240
                }
                message = items.isEmpty ? "拖入图片，自动生成杂志封面" : "已恢复 \(items.count) 本杂志"
                if items.count != restored.count { message += "，部分图片已丢失" }
            }
        } catch {
            message = "无法读取杂志库：\(error.localizedDescription)"
        }
    }

    func imageURL(_ item: MagazineItem) -> URL { images.appendingPathComponent(item.filename) }
    func imageURL(item: MagazineItem) -> URL { imageURL(item) }

    func importURLs(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        let previousItems = items
        var added: [URL] = []
        var duplicate = 0
        var failures = 0
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                guard url.isFileURL else { throw ImportError.invalidImage }
                let bytes = try Data(contentsOf: url)
                guard let source = NSImage(data: bytes),
                      let cgImage = source.cgImage(forProposedRect: nil, context: nil, hints: nil),
                      cgImage.width > 0, cgImage.height > 0,
                      let png = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
                else { throw ImportError.invalidImage }
                let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
                let filename = digest + ".png"
                if items.contains(where: { $0.filename == filename }) { duplicate += 1; continue }
                let destination = images.appendingPathComponent(filename)
                try png.write(to: destination, options: .atomic)
                added.append(destination)
                items.append(MagazineItem(filename: filename, template: Int.random(in: style.range),
                                          seed: Int.random(in: 0..<Int.max), originalName: url.lastPathComponent))
            } catch { failures += 1 }
        }
        do {
            try persist()
            let count = items.count - previousItems.count
            if count > 0 { page = (previousItems.count / 8) }
            var parts = ["已添加 \(count) 张图片"]
            if duplicate > 0 { parts.append("跳过 \(duplicate) 张重复图片") }
            if failures > 0 { parts.append("\(failures) 个文件无法读取或不是图片") }
            message = parts.joined(separator: " · ")
        } catch {
            items = previousItems
            for url in added { try? manager.removeItem(at: url) }
            message = "保存失败，未导入图片：\(error.localizedDescription)"
        }
    }

    func setStyle(_ selected:CoverStyle) {
        do {
            try JSONEncoder().encode(selected).write(to:root.appendingPathComponent("style.json"),options:.atomic)
            style=selected
            shuffleTemplates()
            if items.isEmpty {message="已选择\(selected.title)，拖入图片即可"}
        } catch {message="风格设置未保存，请重试"}
    }
    private func nextTemplate(after previous:Int)->Int {
        var value=Int.random(in:style.range)
        if value==previous {value=style.range.lowerBound+(value-style.range.lowerBound+1)%style.range.count}
        return value
    }

    func shuffleTemplates() {
        guard !items.isEmpty else { message = "先拖入几张图片吧"; return }
        let old = items
        for index in items.indices {
            // Always produce a different cover, including when random happens to repeat.
            items[index].template = nextTemplate(after:items[index].template)
            items[index].seed = Int.random(in: 0..<Int.max)
        }
        do { try persist(); message = "已为 \(items.count) 本杂志重新排版" }
        catch { items = old; message = "排版未保存：\(error.localizedDescription)" }
    }

    func reroll(_ item: MagazineItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let old = items
        items[index].template = nextTemplate(after:items[index].template)
        items[index].seed = Int.random(in: 0..<Int.max)
        do { try persist(); message = "已更换封面模板" }
        catch { items = old; message = "排版未保存：\(error.localizedDescription)" }
    }

    func remove(_ item: MagazineItem) {
        guard items.contains(where: { $0.id == item.id }) else { return }
        let old = items
        items.removeAll { $0.id == item.id }
        do {
            try persist()
            if isOwnedFilename(item.filename), !items.contains(where: { $0.filename == item.filename }) {
                try? manager.removeItem(at: imageURL(item))
            }
            page = min(max(page, 0), pages - 1)
            message = "已移出杂志架，原始图片保留"
        } catch { items = old; message = "移除失败：\(error.localizedDescription)" }
    }

    private func persist() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(items).write(to: manifest, options: .atomic)
    }

    private func isOwnedFilename(_ filename: String) -> Bool {
        filename.count == 68 && filename.hasSuffix(".png") && filename.prefix(64).allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }

    private enum ImportError: Error { case invalidImage }
}
