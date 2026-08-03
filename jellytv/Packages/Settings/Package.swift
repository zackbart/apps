// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Settings",
    platforms: [.tvOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "Settings", targets: ["Settings"]),
    ],
    dependencies: [
        .package(path: "../JellyfinAPI"),
        .package(path: "../Persistence"),
        .package(path: "../DesignSystem"),
    ],
    targets: [
        .target(
            name: "Settings",
            dependencies: [
                .product(name: "JellyfinAPI", package: "JellyfinAPI"),
                .product(name: "Persistence", package: "Persistence"),
                .product(name: "DesignSystem", package: "DesignSystem"),
            ]
        ),
        .testTarget(
            name: "SettingsTests",
            dependencies: ["Settings", "JellyfinAPI"]
        ),
    ]
)
