// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DumboCore",
    platforms: [.macOS(.v13)],
    products: [.library(name: "DumboCore", targets: ["DumboCore"])],
    targets: [
        .target(name: "DumboCore", path: "Dumbo/Shared", exclude: ["ScreenTimeController.swift"]),
        .testTarget(name: "DumboCoreTests", dependencies: ["DumboCore"])
    ]
)
