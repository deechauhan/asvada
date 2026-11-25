// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Features",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "Features", targets: ["Features"]),
    ],
    dependencies: [
        .package(path: "../Core/DesignSystem"),
        .package(path: "../Core/Geo"),
        .package(path: "../Core/Model"),
        .package(path: "../Core/Ranking"),
        .package(path: "../Core/Storage"),
    ],
    targets: [
        .target(
            name: "Features",
            dependencies: [
                "DesignSystem",
                "Geo",
                "Model",
                "Ranking",
                "Storage",
            ],
        ),
        .testTarget(
            name: "FeaturesTests",
            dependencies: ["DesignSystem", "Features", "Geo", "Model", "Storage"],
        ),
    ],
)
