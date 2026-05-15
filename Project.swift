import ProjectDescription

// Tuist project manifest. Mirrors Package.swift: five modules + one executable
// + three test targets. Generates a runnable Xcode project from the same
// `Sources/` and `Tests/` directories SPM uses.
//
// Why both?
//   • `swift build` / `swift test` is canonical (used by CI and for
//     fast module-level iteration).
//   • Tuist gives Xcode users a proper `.app` target with Info.plist,
//     entitlements, and a Run scheme — `swift build` produces a plain
//     executable that can't be launched as a sandboxed app from Xcode.

let bundleIdPrefix = "io.galva"
let deploymentTargets: DeploymentTargets = .macOS("14.0")

let baseSettings: SettingsDictionary = [
    "SWIFT_VERSION": "5.10",
    "MACOSX_DEPLOYMENT_TARGET": "14.0",
    "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
    "SWIFT_TREAT_WARNINGS_AS_ERRORS": "NO",
    // Ad-hoc signing by default so contributors can `tuist generate && xcodebuild`
    // without provisioning a Developer ID. Release builds in `.github/workflows/release.yml`
    // override these.
    "CODE_SIGN_STYLE": "Manual",
    "CODE_SIGN_IDENTITY": "-",
    "DEVELOPMENT_TEAM": "",
    "CODE_SIGNING_REQUIRED": "YES",
    "CODE_SIGNING_ALLOWED": "YES"
]

// MARK: - Module factory

func framework(name: String, dependencies: [TargetDependency] = []) -> Target {
    .target(
        name: name,
        destinations: .macOS,
        product: .staticFramework,
        bundleId: "\(bundleIdPrefix).peel.\(name.lowercased())",
        deploymentTargets: deploymentTargets,
        infoPlist: .default,
        sources: ["Sources/\(name)/**"],
        dependencies: dependencies,
        settings: .settings(base: baseSettings)
    )
}

func unitTests(name: String, depends: [String]) -> Target {
    .target(
        name: name,
        destinations: .macOS,
        product: .unitTests,
        bundleId: "\(bundleIdPrefix).peel.\(name.lowercased())",
        deploymentTargets: deploymentTargets,
        infoPlist: .default,
        sources: ["Tests/\(name)/**"],
        dependencies: depends.map { .target(name: $0) },
        settings: .settings(base: baseSettings)
    )
}

// MARK: - Targets

let peelCore = framework(name: "PeelCore")
let peelAPI = framework(name: "PeelAPI", dependencies: [.target(name: "PeelCore")])
let peelPersistence = framework(name: "PeelPersistence", dependencies: [.target(name: "PeelCore")])
let peelUI = framework(
    name: "PeelUI",
    dependencies: [
        .target(name: "PeelCore"),
        .target(name: "PeelAPI"),
        .target(name: "PeelPersistence")
    ]
)

let peelApp = Target.target(
    name: "Peel",
    destinations: .macOS,
    product: .app,
    productName: "Peel",
    bundleId: "\(bundleIdPrefix).peel",
    deploymentTargets: deploymentTargets,
    infoPlist: .file(path: "Resources/Info.plist"),
    sources: ["Sources/PeelApp/**"],
    resources: ["Sources/PeelApp/Resources/**"],
    // Tuist generates an Xcode project for local development; ad-hoc
    // signing there can't resolve $(AppIdentifierPrefix), so we point at
    // the dev entitlements file (no keychain-access-groups). The release
    // workflow signs with Developer ID and uses Resources/Peel.entitlements.
    entitlements: .file(path: "Resources/Peel-dev.entitlements"),
    dependencies: [
        .target(name: "PeelCore"),
        .target(name: "PeelAPI"),
        .target(name: "PeelPersistence"),
        .target(name: "PeelUI")
    ],
    settings: .settings(base: baseSettings)
)

let tests: [Target] = [
    unitTests(name: "PeelCoreTests", depends: ["PeelCore"]),
    unitTests(name: "PeelAPITests", depends: ["PeelAPI", "PeelCore"]),
    unitTests(name: "PeelPersistenceTests", depends: ["PeelPersistence", "PeelCore"])
]

let project = Project(
    name: "Peel",
    organizationName: "Galva",
    options: .options(
        defaultKnownRegions: ["en"],
        developmentRegion: "en"
    ),
    settings: .settings(
        base: baseSettings,
        configurations: [
            .debug(name: "Debug"),
            .release(name: "Release")
        ]
    ),
    targets: [
        peelApp,
        peelCore,
        peelAPI,
        peelPersistence,
        peelUI
    ] + tests,
    schemes: [
        .scheme(
            name: "Peel",
            shared: true,
            buildAction: .buildAction(targets: ["Peel"]),
            testAction: .targets(
                tests.map { TestableTarget.testableTarget(target: .target($0.name)) },
                configuration: .debug,
                options: .options(coverage: true)
            ),
            runAction: .runAction(
                configuration: .debug,
                executable: "Peel"
            ),
            archiveAction: .archiveAction(configuration: .release)
        )
    ]
)
