// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Sources",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "Sources", targets: ["Sources"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Sources",
            dependencies: [
            ]
        ),
        .testTarget(
            name: "SourcesTests",
            dependencies: ["Sources"]
        ),
    ]
)
