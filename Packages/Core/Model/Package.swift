// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Model",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "Model", targets: ["Model"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Model",
            dependencies: [
            ]
        ),
        .testTarget(
            name: "ModelTests",
            dependencies: ["Model"]
        ),
    ]
)
