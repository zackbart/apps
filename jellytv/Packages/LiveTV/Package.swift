// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LiveTV",
    platforms: [.tvOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "LiveTV", targets: ["LiveTV"]),
    ],
    dependencies: [
        .package(path: "../JellyfinAPI"),
        .package(path: "../DesignSystem"),
        .package(url: "https://github.com/kean/Nuke", from: "12.0.0"),
    ],
    targets: [
        .target(
            name: "LiveTV",
            dependencies: [
                .product(name: "JellyfinAPI", package: "JellyfinAPI"),
                .product(name: "DesignSystem", package: "DesignSystem"),
                .product(name: "NukeUI", package: "Nuke"),
            ]
        ),
        .testTarget(
            name: "LiveTVTests",
            dependencies: ["LiveTV"]
        ),
    ]
)
