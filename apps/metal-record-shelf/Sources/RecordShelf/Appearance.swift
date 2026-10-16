import Foundation

enum RackSkin: String, CaseIterable, Codable, Identifiable {
    case silver, graphite, cream, sage, walnut, rams
    var id: String { rawValue }
    var displayName: String {
        switch self { case .silver: return "工业铝制唱片架"; case .graphite: return "洞洞板工作室"; case .cream: return "极简画廊架"; case .sage: return "磨砂亚克力展架"; case .walnut: return "胡桃木格柜"; case .rams: return "功能主义器材架" }
    }
}
enum DiscStyle: String, CaseIterable, Codable, Identifiable {
    case mixed, glass, silver, black, amber, rose, jade
    var id: String { rawValue }
    var displayName: String {
        switch self { case .mixed: return "混合彩胶"; case .glass: return "封面晕染玻璃"; case .silver: return "银色唱片"; case .black: return "经典黑胶"; case .amber: return "琥珀透明"; case .rose: return "玫瑰粉胶"; case .jade: return "翡翠绿胶" }
    }
}
struct ShelfItemStyle: Equatable {
    let isDisc: Bool
    let size: Double
    let xOffset: Double
}
struct ShelfDisplayItem: Identifiable, Equatable {
    let album: RecordAlbum
    let isCompanion: Bool
    var id: String { album.id + (isCompanion ? "-companion" : "-primary") }
}
enum ShelfArrangement {
    // Stable across launches; never use Swift's process-randomized hashValue for a saved layout.
    static func hash(_ id: String, seed: UInt64) -> UInt64 {
        var value = 14695981039346656037 ^ seed
        for byte in id.utf8 { value = (value ^ UInt64(byte)) &* 1099511628211 }
        value ^= value >> 33; value &*= 0xff51afd7ed558ccd
        value ^= value >> 33; value &*= 0xc4ceb9fe1a85ec53
        return value ^ (value >> 33)
    }
    static func ordered(_ albums: [RecordAlbum], seed: UInt64) -> [RecordAlbum] {
        guard seed != 0 else { return albums }
        return albums.sorted {
            let a = hash($0.id, seed: seed), b = hash($1.id, seed: seed)
            return a == b ? $0.id < $1.id : a < b
        }
    }
    static func displayItems(_ albums: [RecordAlbum], seed: UInt64) -> [ShelfDisplayItem] {
        var items = albums.prefix(9).map { ShelfDisplayItem(album: $0, isCompanion: false) }
        if albums.count == 8, let album = albums.min(by: { hash($0.id, seed: seed) < hash($1.id, seed: seed) }) {
            let position = Int(hash("companion", seed: seed) % 9)
            items.insert(ShelfDisplayItem(album: album, isCompanion: true), at: position)
        }
        return items
    }
    static func rows<T>(_ albums: [T], seed: UInt64) -> [[T]] {
        let page = Array(albums.prefix(9))
        var counts = (0..<3).map { min(3, max(0, page.count - $0 * 3)) }
        let shift = Int(hash("row-counts", seed: seed) % 3)
        counts = Array(counts[shift...] + counts[..<shift])
        var offset = 0
        return counts.map { count in
            defer { offset += count }
            return Array(page[offset..<(offset + count)])
        }
    }
    static func style(for id: String, seed: UInt64, index: Int) -> ShelfItemStyle {
        let value = hash(id, seed: seed ^ 0x6a09e667f3bcc909)
        return ShelfItemStyle(isDisc: index % 3 == Int(seed % 3) || value % 11 < 4, size: Double(76 + (value >> 8) % 13), xOffset: Double(Int((value >> 16) % 9) - 4))
    }
    static func color(for id: String, seed: UInt64) -> DiscStyle {
        let choices: [DiscStyle] = [.glass, .amber, .rose, .jade, .glass]
        return choices[Int(hash(id, seed: seed ^ 0xbb67ae8584caa73b) % UInt64(choices.count))]
    }
}
