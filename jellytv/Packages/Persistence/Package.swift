// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Persistence",
    platforms: [.tvOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "Persistence", targets: ["Persistence"]),
    ],
    targets: [
        .target(name: "Persistence"),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence"]),
    ]
)
