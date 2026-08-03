// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "JellyfinAPI",
    platforms: [.tvOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "JellyfinAPI", targets: ["JellyfinAPI"]),
    ],
    targets: [
        .target(name: "JellyfinAPI"),
        .testTarget(name: "JellyfinAPITests", dependencies: ["JellyfinAPI"]),
    ]
)
