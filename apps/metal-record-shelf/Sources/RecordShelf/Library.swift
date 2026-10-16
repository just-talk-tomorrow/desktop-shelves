import Foundation

struct RecordAlbum: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let artist: String
    let artwork: URL?
}
struct ShelfLibrary: Codable, Equatable {
    var manual: [RecordAlbum] = []
    var cloud: [RecordAlbum] = []
    var nickname: String? = nil
    var hidden: Set<String>? = nil
    var albums: [RecordAlbum] {
        var seen = Set<String>()
        return (manual + cloud).filter { !(hidden ?? []).contains($0.id) && seen.insert($0.id).inserted }
    }
    var pageCount: Int { max(1, (albums.count + 8) / 9) }
    func items(on page: Int) -> [RecordAlbum] {
        guard page >= 0, page < pageCount else { return [] }
        return Array(albums.dropFirst(page * 9).prefix(9))
    }
    static func albumID(from input: String) -> String? {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if validID(value) { return value }
        guard let url = URL(string: value), let host = url.host?.lowercased(),
              ["music.163.com", "y.music.163.com"].contains(host), ["https", "http", "orpheus"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        let pattern = #"(?:album\?[^#]*?\bid=|album/)([0-9]{1,20})(?:\D|$)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
              let range = Range(match.range(at: 1), in: value) else { return nil }
        let id = String(value[range]); return validID(id) ? id : nil
    }
    private static func validID(_ value: String) -> Bool {
        !value.isEmpty && value.count <= 20 && value.allSatisfy { $0.isASCII && $0.isNumber } && value.contains { $0 != "0" }
    }
}

struct LibraryDisk {
    let root: URL
    var file: URL { root.appendingPathComponent("library.json") }
    func load() throws -> ShelfLibrary {
        guard FileManager.default.fileExists(atPath: file.path) else { return ShelfLibrary() }
        return try JSONDecoder().decode(ShelfLibrary.self, from: Data(contentsOf: file))
    }
    func save(_ library: ShelfLibrary) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try JSONEncoder().encode(library).write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }
}
