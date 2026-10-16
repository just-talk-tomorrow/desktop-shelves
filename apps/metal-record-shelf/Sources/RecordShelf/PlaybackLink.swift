import Foundation

enum NeteasePlaybackLink {
    static func song(_ id: String) -> URL? {
        guard !id.isEmpty, id.allSatisfy({ $0.isASCII && $0.isNumber }),
              let number = Int64(id), number > 0,
              let data = try? JSONSerialization.data(withJSONObject: ["type": "song", "id": number, "cmd": "play"], options: [.sortedKeys]) else { return nil }
        // The Mac player expects Base64 JSON, unlike the mobile song/id route.
        // Keep the encoded text's case intact; do not rebuild/lowercase its host.
        return URL(string: "orpheus://" + data.base64EncodedString())
    }
}
