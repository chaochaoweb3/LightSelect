// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "LightSelect",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "LightSelect",
            path: "Sources/LightSelect"
        )
    ]
)
