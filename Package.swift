// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SlowWave",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AudioSlowDownCore",
            targets: ["AudioSlowDownCore"]
        ),
        .executable(
            name: "SlowWave",
            targets: ["SlowWave"]
        )
    ],
    targets: [
        .target(
            name: "AudioSlowDownCore"
        ),
        .executableTarget(
            name: "SlowWave",
            dependencies: ["AudioSlowDownCore"],
            path: "Sources/AudioSlowDown"
        ),
        .testTarget(
            name: "AudioSlowDownCoreTests",
            dependencies: ["AudioSlowDownCore"]
        )
    ]
)
