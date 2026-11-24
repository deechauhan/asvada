// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Storage",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "Storage", targets: ["Storage"]),
    ],
    dependencies: [
        .package(path: "../Geo"),
        .package(path: "../Model"),
        .package(path: "../Ranking"),
    ],
    targets: [
        .target(
            name: "Storage",
            dependencies: [
                "Geo",
                "Model",
                "Ranking",
            ],
        ),
        .testTarget(
            name: "StorageTests",
            dependencies: ["Geo", "Ranking", "Storage"],
        ),
    ],
)
