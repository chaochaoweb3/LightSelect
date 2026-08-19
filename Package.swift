// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "LightSelect",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "LightSelectCore",
            dependencies: ["SelectionHookNative"],
            path: "Sources/LightSelectCore",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Security"),
                .linkedFramework("WebKit")
            ]
        ),
        .target(
            name: "SelectionHookNative",
            path: "Sources/SelectionHookNative",
            publicHeadersPath: "include",
            cxxSettings: [.unsafeFlags(["-std=c++17"])],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon")
            ]
        ),
        .executableTarget(
            name: "LightSelect",
            dependencies: ["LightSelectCore"],
            path: "Sources/LightSelect"
        ),
        .executableTarget(
            name: "LightSelectCoreContractTests",
            dependencies: ["LightSelectCore"],
            path: "Tests/LightSelectCoreContractTests"
        ),
        .testTarget(
            name: "LightSelectCoreTests",
            dependencies: ["LightSelectCore"],
            path: "Tests/LightSelectCoreTests"
        )
    ]
)
