import Foundation

struct MusicLibraryResult: Sendable {
    let albums: [RecordAlbum]
    let likedSongCount: Int
    let missingSongCount: Int
    let skippedAlbumCount: Int
}

struct MusicLibrarySync {
    let bridge: any MusicRequesting

    func fetch(cookie: String, progress: @MainActor @Sendable (String) -> Void) async throws -> MusicLibraryResult {
        struct Start: Decodable { let likedSongIDs: [String]; let likedSongCount: Int; let truncated: Bool }
        struct Page: Decodable { let albums: [RecordAlbum]; let nextOffset: Int?; let truncated: Bool }
        struct Batch: Decodable {
            let albums: [RecordAlbum]
            let requestedCount: Int
            let resolvedSongCount: Int
            let missingSongCount: Int
            let skippedAlbumCount: Int
        }
        await progress("正在读取我喜欢的音乐…")
        let start = try JSONDecoder().decode(Start.self, from: await bridge.call("libraryStart", fields: ["cookie": cookie]))
        guard !start.truncated, start.likedSongIDs.count == start.likedSongCount else {
            throw MusicFailure(message: "喜欢的歌曲超出接口读取范围，未覆盖原有清单。")
        }
        var albums: [RecordAlbum] = [], seen = Set<String>()
        func append(_ values: [RecordAlbum]) {
            for album in values where seen.insert(album.id).inserted { albums.append(album) }
        }
        var offset = 0, pageOffsets = Set<Int>()
        while true {
            try Task.checkCancellation()
            guard pageOffsets.insert(offset).inserted else { throw MusicFailure(message: "收藏专辑分页未能完成，请重试。") }
            await progress("正在读取收藏专辑 · 已读取 \(albums.count) 张")
            let page = try JSONDecoder().decode(Page.self, from: await bridge.call("subscribedPage", fields: ["cookie": cookie, "offset": String(offset)]))
            guard !page.truncated else { throw MusicFailure(message: "收藏专辑超出接口读取范围，未覆盖原有清单。") }
            append(page.albums)
            guard let next = page.nextOffset else { break }
            guard next > offset else { throw MusicFailure(message: "收藏专辑分页无效，请重试。") }
            offset = next
        }
        var missing = 0, skipped = 0
        for offset in stride(from: 0, to: start.likedSongIDs.count, by: 200) {
            try Task.checkCancellation()
            let ids = Array(start.likedSongIDs[offset..<min(offset + 200, start.likedSongIDs.count)])
            await progress("喜欢的音乐 \(offset)/\(start.likedSongCount) 首 · \(albums.count) 张专辑")
            let batch = try JSONDecoder().decode(Batch.self, from: await bridge.call("likedAlbums", fields: ["cookie": cookie, "ids": ids.joined(separator: ",")]))
            guard batch.requestedCount == ids.count, batch.resolvedSongCount + batch.missingSongCount == ids.count,
                  batch.missingSongCount >= 0, batch.skippedAlbumCount >= 0 else {
                throw MusicFailure(message: "喜欢歌曲的专辑资料返回不完整，未覆盖原有清单。")
            }
            append(batch.albums); missing += batch.missingSongCount; skipped += batch.skippedAlbumCount
        }
        return MusicLibraryResult(albums: albums, likedSongCount: start.likedSongCount, missingSongCount: missing, skippedAlbumCount: skipped)
    }
}
