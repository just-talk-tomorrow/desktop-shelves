import AppKit
import Combine
import Foundation
import Darwin

struct ShelfItem: Codable, Identifiable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable { case file, folder, text, image, link }
    let id: UUID
    let filename: String
    let displayName: String
    let kind: Kind
    let createdAt: Date
}

/// The shelf owns its copies. It never stores a reference to the user's original file.
@MainActor
final class ShelfStore: ObservableObject {
    @Published private(set) var items: [ShelfItem] = []
    @Published var error: String?
    @Published private(set) var importing = false
    let rootURL: URL
    private var writable = true
    var pageCount: Int { max(1, (items.count + 7) / 8) }

    init(rootURL: URL? = nil) {
        self.rootURL = rootURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Codex Pacer Shelf", isDirectory: true)
        do {
            items = try ShelfDisk.load(root: self.rootURL)
            if items.contains(where: { !FileManager.default.fileExists(atPath: url(for: $0).path) }) {
                error = "部分暂存文件已丢失；记录已保留，请移除失效条目。"
            }
        } catch {
            writable = false
            self.error = "暂存目录无法读取，或清单已损坏。原文件和清单已保留，暂未写入新内容。"
        }
    }

    func url(for item: ShelfItem) -> URL {
        rootURL.appendingPathComponent("Items", isDirectory: true)
            .appendingPathComponent(item.id.uuidString, isDirectory: true)
            .appendingPathComponent(item.filename)
    }

    func items(on page: Int) -> [ShelfItem] {
        guard page >= 0, page < pageCount else { return [] }
        return Array(items.dropFirst(page * 8).prefix(8))
    }

    @discardableResult
    func importURLs(_ urls: [URL]) async -> Int {
        await insert(urls.map { .file($0) })
    }

    @discardableResult
    func importText(_ text: String) async -> Int {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return 0 }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.host != nil,
           let data = try? PropertyListSerialization.data(fromPropertyList: ["URL": trimmed], format: .xml, options: 0) {
            return await insert([.data(data, "链接.webloc", .link)])
        }
        return await insert([.data(Data(text.utf8), "文本.txt", .text)])
    }

    @discardableResult
    func importImage(_ image: NSImage) async -> Int {
        guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:]) else {
            error = "图片无法转换为 PNG，请重试。"
            return 0
        }
        return await insert([.data(data, "图片.png", .image)])
    }

    private func insert(_ inputs: [ShelfDisk.Input]) async -> Int {
        guard !inputs.isEmpty else { return 0 }
        guard writable else { return 0 }
        guard !importing else { error = "正在保存暂存内容，请稍后重试。"; return 0 }
        importing = true
        defer { importing = false }
        let root = rootURL, previous = items
        let result = await Task.detached(priority: .userInitiated) {
            ShelfDisk.insert(inputs, root: root, previous: previous)
        }.value
        items = result.items
        error = result.error
        return result.count
    }

    /// Only the managed copy is trashed, never the user's original.
    @discardableResult
    func remove(_ item: ShelfItem) async -> Bool {
        guard writable, !importing, items.contains(where: { $0.id == item.id }) else { return false }
        importing = true
        defer { importing = false }
        let root = rootURL, previous = items
        let result = await Task.detached(priority: .userInitiated) {
            ShelfDisk.remove(item, root: root, previous: previous)
        }.value
        items = result.items
        error = result.error
        return result.count == 1
    }
}

private enum ShelfDisk {
    enum Input: Sendable { case file(URL), data(Data, String, ShelfItem.Kind) }
    struct Manifest: Codable { let version: Int; let items: [ShelfItem] }
    struct Result: Sendable { let items: [ShelfItem]; let count: Int; let error: String? }

    static func load(root: URL) throws -> [ShelfItem] {
        let manager = FileManager.default
        // Never treat an unreadable/corrupt existing manifest as an empty shelf.
        let manifest = root.appendingPathComponent("manifest.json")
        if manager.fileExists(atPath: manifest.path) {
            let decoded = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: manifest))
            guard decoded.version == 1, Set(decoded.items.map(\.id)).count == decoded.items.count,
                  decoded.items.allSatisfy({ validName($0.filename) }) else { throw CocoaError(.fileReadCorruptFile) }
            return decoded.items
        }
        // A missing manifest beside existing copies needs recovery, not an implicit reset.
        let copies = root.appendingPathComponent("Items", isDirectory: true)
        if manager.fileExists(atPath: copies.path), !(try manager.contentsOfDirectory(atPath: copies.path)).isEmpty {
            throw CocoaError(.fileReadCorruptFile)
        }
        return []
    }

    static func validName(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." && !name.contains("/") && !name.contains("\0")
    }

    static func prepare(root: URL) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
        try manager.createDirectory(at: root.appendingPathComponent("Items"), withIntermediateDirectories: true,
                                    attributes: [.posixPermissions: 0o700])
    }

    static func save(_ items: [ShelfItem], root: URL) throws {
        let data = try JSONEncoder().encode(Manifest(version: 1, items: items))
        let target = root.appendingPathComponent("manifest.json")
        let staging = root.appendingPathComponent(".manifest-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: staging) }
        try data.write(to: staging, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: staging.path)
        guard rename(staging.path, target.path) == 0 else { throw CocoaError(.fileWriteUnknown) }
    }

    static func checkCopyable(_ url: URL) throws -> Bool {
        let keys: Set<URLResourceKey> = [.isSymbolicLinkKey, .isDirectoryKey, .isRegularFileKey]
        let values = try url.resourceValues(forKeys: keys)
        guard values.isSymbolicLink != true else { throw CocoaError(.fileReadUnsupportedScheme) }
        guard values.isDirectory == true || values.isRegularFile == true else { throw CocoaError(.fileReadUnsupportedScheme) }
        if values.isDirectory == true {
            guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(keys),
                errorHandler: { _, _ in false }) else { throw CocoaError(.fileReadUnknown) }
            for case let child as URL in enumerator {
                let value = try child.resourceValues(forKeys: keys)
                guard value.isSymbolicLink != true, value.isDirectory == true || value.isRegularFile == true else {
                    throw CocoaError(.fileReadUnsupportedScheme)
                }
            }
        }
        return values.isDirectory == true
    }

    static func insert(_ inputs: [Input], root: URL, previous: [ShelfItem]) -> Result {
        let manager = FileManager.default
        var added: [ShelfItem] = [], directories: [URL] = [], failures = 0
        do {
            try prepare(root: root)
            for input in inputs {
                let id = UUID()
                let destinationDirectory = root.appendingPathComponent("Items/\(id.uuidString)")
                do {
                    let name: String, kind: ShelfItem.Kind
                    switch input {
                    case .file(let source):
                        name = source.lastPathComponent
                        kind = try checkCopyable(source) ? .folder : .file
                    case .data(_, let filename, let dataKind): name = filename; kind = dataKind
                    }
                    guard validName(name) else { throw CocoaError(.fileReadInvalidFileName) }
                    try manager.createDirectory(at: destinationDirectory, withIntermediateDirectories: false,
                                                attributes: [.posixPermissions: 0o700])
                    let destination = destinationDirectory.appendingPathComponent(name)
                    switch input {
                    case .file(let source):
                        let scoped = source.startAccessingSecurityScopedResource()
                        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
                        try manager.copyItem(at: source, to: destination)
                        _ = try checkCopyable(destination)
                    case .data(let data, _, _): try data.write(to: destination, options: .atomic)
                    }
                    added.append(ShelfItem(id: id, filename: name, displayName: name, kind: kind, createdAt: Date()))
                    directories.append(destinationDirectory)
                } catch {
                    try? manager.removeItem(at: destinationDirectory)
                    failures += 1
                }
            }
            guard !added.isEmpty else {
                return Result(items: previous, count: 0, error: "未能导入文件。请检查文件是否存在、可读取；符号链接不支持暂存。")
            }
            try save(previous + added, root: root)
            return Result(items: previous + added, count: added.count,
                          error: failures == 0 ? nil : "\(failures) 个项目未能导入，其余内容已保存。")
        } catch {
            for directory in directories { try? manager.removeItem(at: directory) }
            return Result(items: previous, count: 0, error: "暂存保存失败，已有记录和原文件均已保留。")
        }
    }

    static func remove(_ item: ShelfItem, root: URL, previous: [ShelfItem]) -> Result {
        let manager = FileManager.default, next = previous.filter { $0.id != item.id }
        let directory = root.appendingPathComponent("Items/\(item.id.uuidString)")
        let staged = root.appendingPathComponent("Removing-\(item.id.uuidString)")
        var moved = false
        do {
            if manager.fileExists(atPath: directory.path) {
                try manager.moveItem(at: directory, to: staged)
                moved = true
            }
            do { try save(next, root: root) }
            catch {
                if moved { try? manager.moveItem(at: staged, to: directory) }
                throw error
            }
            if moved {
                do { try manager.trashItem(at: staged, resultingItemURL: nil) }
                catch {
                    // Keep the recoverable copy when the system Trash is unavailable.
                    return Result(items: next, count: 1, error: "条目已移出，系统废纸篓不可用；副本仍保留在暂存恢复目录。")
                }
            }
            return Result(items: next, count: 1, error: nil)
        } catch {
            return Result(items: previous, count: 0, error: "移除失败，暂存内容已保留。")
        }
    }
}
