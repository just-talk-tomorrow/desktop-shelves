import Foundation

/// Local shelf builds are a different app; they must never silently exit behind the upstream app's lock.
public struct IslandInstanceIdentity: Equatable, Sendable {
    public let directory: String
    public let notification: String
    public init(bundleIdentifier: String?, shelfBuild: Bool) {
        if shelfBuild {
            let id = bundleIdentifier ?? "com.local.codexpacer.shelf"
            directory = id + "/Runtime"
            notification = id + ".showExistingInstance"
        } else {
            directory = "CodexPacerIsland"
            notification = "com.codexpacer.island.showExistingInstance"
        }
    }
}
