// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Sources",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "Sources", targets: ["Sources"]),
    ],
    targets: [
        .target(
            name: "Sources",
            resources: [.process("Resources")],
        ),
        .testTarget(
            name: "SourcesTests",
            dependencies: ["Sources"],
        ),
    ],
)
