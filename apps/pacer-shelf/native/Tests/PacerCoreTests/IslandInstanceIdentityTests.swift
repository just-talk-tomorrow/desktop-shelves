import XCTest
@testable import PacerCore

final class IslandInstanceIdentityTests: XCTestCase {
    func testShelfDoesNotExitBehindOfficialAppAndKeepsOneOwnInstance() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: base) }
        let official = IslandInstanceIdentity(bundleIdentifier: "com.codexpacer.app", shelfBuild: false)
        let shelf = IslandInstanceIdentity(bundleIdentifier: "com.local.codexpacer.shelf", shelfBuild: true)
        XCTAssertNotEqual(official.notification, shelf.notification)
        let upstream = try IslandInstanceLock(at: base.appendingPathComponent(official.directory + "/instance.lock"))
        let custom = try IslandInstanceLock(at: base.appendingPathComponent(shelf.directory + "/instance.lock"))
        XCTAssertTrue(upstream.acquired)
        XCTAssertTrue(custom.acquired)
        XCTAssertFalse(try IslandInstanceLock(at: base.appendingPathComponent(shelf.directory + "/instance.lock")).acquired)
    }
    func testOfficialIdentityRemainsCompatible() {
        let identity = IslandInstanceIdentity(bundleIdentifier: nil, shelfBuild: false)
        XCTAssertEqual(identity.directory, "CodexPacerIsland")
        XCTAssertEqual(identity.notification, "com.codexpacer.island.showExistingInstance")
    }
}
