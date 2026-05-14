// swift-tools-version: 5.10
import PackageDescription

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
        .library(name: "PeelWebhook", targets: ["PeelWebhook"]),
        .library(name: "PeelUI", targets: ["PeelUI"])
    ],
    targets: [
        .target(
            name: "PeelCore",
            path: "Sources/PeelCore"
        ),
        .target(
            name: "PeelAPI",
            dependencies: ["PeelCore"],
            path: "Sources/PeelAPI"
        ),
        .target(
            name: "PeelPersistence",
            dependencies: ["PeelCore"],
            path: "Sources/PeelPersistence"
        ),
        .target(
            name: "PeelWebhook",
            dependencies: ["PeelCore"],
            path: "Sources/PeelWebhook"
        ),
        .target(
            name: "PeelUI",
            dependencies: ["PeelCore", "PeelAPI", "PeelPersistence", "PeelWebhook"],
            path: "Sources/PeelUI"
        ),
        .executableTarget(
            name: "PeelApp",
            dependencies: ["PeelCore", "PeelAPI", "PeelPersistence", "PeelWebhook", "PeelUI"],
            path: "Sources/PeelApp",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "PeelCoreTests",
            dependencies: ["PeelCore"],
            path: "Tests/PeelCoreTests"
        ),
        .testTarget(
            name: "PeelAPITests",
            dependencies: ["PeelAPI", "PeelCore"],
            path: "Tests/PeelAPITests"
        ),
        .testTarget(
            name: "PeelPersistenceTests",
            dependencies: ["PeelPersistence", "PeelCore"],
            path: "Tests/PeelPersistenceTests"
        ),
        .testTarget(
            name: "PeelWebhookTests",
            dependencies: ["PeelWebhook", "PeelCore"],
            path: "Tests/PeelWebhookTests"
        )
    ]
)
