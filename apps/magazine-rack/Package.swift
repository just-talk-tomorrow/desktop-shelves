// swift-tools-version: 5.10
import PackageDescription
let package = Package(name: "MagazineRack", platforms: [.macOS(.v14)], products: [.executable(name:"MagazineRack",targets:["MagazineRack"])], targets:[.executableTarget(name:"MagazineRack"),.testTarget(name:"MagazineRackTests",dependencies:["MagazineRack"])])
