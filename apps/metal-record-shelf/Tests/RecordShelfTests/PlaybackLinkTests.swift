import XCTest
@testable import RecordShelf

final class PlaybackLinkTests: XCTestCase {
    func testMacLinkContainsNumericSongAndPlayCommandWithoutChangingBase64Case() throws {
        let url = try XCTUnwrap(NeteasePlaybackLink.song("210049"))
        XCTAssertTrue(url.absoluteString.hasPrefix("orpheus://"))
        let encoded = String(url.absoluteString.dropFirst("orpheus://".count))
        let data = try XCTUnwrap(Data(base64Encoded: encoded))
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(payload["type"] as? String, "song")
        XCTAssertEqual(payload["cmd"] as? String, "play")
        XCTAssertEqual(payload["id"] as? Int, 210049)
        XCTAssertFalse(url.absoluteString.contains("/album/"))
        XCTAssertFalse(url.absoluteString.contains("/song/"))
    }
    func testInvalidSongCannotCreateAPlaybackRequest() {
        for id in ["", "0", "-1", "１２", "12?cmd=delete", "9999999999999999999999999"] {
            XCTAssertNil(NeteasePlaybackLink.song(id), id)
        }
    }
}
