// swift-tools-version: 5.10
import PackageDescription
let package = Package(name: "MetalRecordShelf", platforms: [.macOS(.v14)], products: [.executable(name: "MetalRecordShelf", targets: ["RecordShelf"])], targets: [.executableTarget(name: "RecordShelf"), .testTarget(name: "RecordShelfTests", dependencies: ["RecordShelf"])])
