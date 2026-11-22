// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Ranking",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "Ranking", targets: ["Ranking"]),
    ],
    targets: [
        .target(
            name: "Ranking",
        ),
        .testTarget(
            name: "RankingTests",
            dependencies: ["Ranking"],
        ),
    ],
)
