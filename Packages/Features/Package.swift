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
        .package(path: "../Core/Model"),
        .package(path: "../Core/Storage"),
    ],
    targets: [
        .target(
            name: "Features",
            dependencies: [
                "DesignSystem",
                "Model",
                "Storage",
            ],
        ),
        .testTarget(
            name: "FeaturesTests",
            dependencies: ["DesignSystem", "Features", "Model", "Storage"],
        ),
    ],
)
