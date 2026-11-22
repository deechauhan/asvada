// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Geo",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "Geo", targets: ["Geo"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Geo",
            dependencies: [
            ]
        ),
        .testTarget(
            name: "GeoTests",
            dependencies: ["Geo"]
        ),
    ]
)
