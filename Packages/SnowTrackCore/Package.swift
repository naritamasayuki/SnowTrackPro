// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SnowTrackCore",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SnowTrackCore",
            targets: ["SnowTrackCore"]
        )
    ],
    targets: [
        .target(
            name: "SnowTrackCore",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "SnowTrackCoreTests",
            dependencies: ["SnowTrackCore"]
        )
    ]
)
