// swift-tools-version: 6.0
import PackageDescription

// Every target opts in to Swift 6 language mode. Same setting as Xcode's
// "Strict Concurrency = Complete." We isolate explicitly with @MainActor
// rather than relying on Swift 5's looser inference.
let swift6: [SwiftSetting] = [
    .swiftLanguageMode(.v6)
]

let package = Package(
    name: "Peel",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Peel", targets: ["PeelApp"]),
        .library(name: "PeelCore", targets: ["PeelCore"]),
        .library(name: "PeelAPI", targets: ["PeelAPI"]),
        .library(name: "PeelPersistence", targets: ["PeelPersistence"]),
        .library(name: "PeelUI", targets: ["PeelUI"])
    ],
    targets: [
        .target(
            name: "PeelCore",
            path: "Sources/PeelCore",
            swiftSettings: swift6
        ),
        .target(
            name: "PeelAPI",
            dependencies: ["PeelCore"],
            path: "Sources/PeelAPI",
            swiftSettings: swift6
        ),
        .target(
            name: "PeelPersistence",
            dependencies: ["PeelCore"],
            path: "Sources/PeelPersistence",
            swiftSettings: swift6
        ),
        .target(
            name: "PeelUI",
            dependencies: ["PeelCore", "PeelAPI", "PeelPersistence"],
            path: "Sources/PeelUI",
            swiftSettings: swift6
        ),
        .executableTarget(
            name: "PeelApp",
            dependencies: ["PeelCore", "PeelAPI", "PeelPersistence", "PeelUI"],
            path: "Sources/PeelApp",
            resources: [.process("Resources")],
            swiftSettings: swift6
        ),
        .testTarget(
            name: "PeelCoreTests",
            dependencies: ["PeelCore"],
            path: "Tests/PeelCoreTests",
            swiftSettings: swift6
        ),
        .testTarget(
            name: "PeelAPITests",
            dependencies: ["PeelAPI", "PeelCore"],
            path: "Tests/PeelAPITests",
            swiftSettings: swift6
        ),
        .testTarget(
            name: "PeelPersistenceTests",
            dependencies: ["PeelPersistence", "PeelCore"],
            path: "Tests/PeelPersistenceTests",
            swiftSettings: swift6
        )
    ]
)
