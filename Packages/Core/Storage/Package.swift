// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Storage",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "Storage", targets: ["Storage"]),
    ],
    dependencies: [
        .package(path: "../Model"),
    ],
    targets: [
        .target(
            name: "Storage",
            dependencies: [
                "Model",
            ],
        ),
        .testTarget(
            name: "StorageTests",
            dependencies: ["Storage"],
        ),
    ],
)
