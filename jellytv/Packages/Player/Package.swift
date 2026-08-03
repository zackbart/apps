// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Player",
    platforms: [.tvOS(.v26)],
    products: [
        .library(name: "Player", targets: ["Player"]),
    ],
    targets: [
        .target(name: "Player"),
    ]
)
