// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Sources",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "Sources", targets: ["Sources"]),
    ],
    dependencies: [
        .package(path: "../Geo"),
    ],
    targets: [
        .target(
            name: "Sources",
            dependencies: ["Geo"],
            resources: [.process("Resources")],
        ),
        .testTarget(
            name: "SourcesTests",
            dependencies: ["Geo", "Sources"],
        ),
    ],
)
