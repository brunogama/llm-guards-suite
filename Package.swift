// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "llm-guards-suite",
  platforms: [.macOS(.v13)],
  products: [
    // CLI Executables (product name must match target name for plugin tool lookup)
    .executable(name: "APIGuardCLI", targets: ["APIGuardCLI"]),
    .executable(name: "QualityGuardCLI", targets: ["QualityGuardCLI"]),
    .executable(name: "ChangeGuardCLI", targets: ["ChangeGuardCLI"]),
    // SwiftPM Plugins
    .plugin(name: "APIGuardPlugin", targets: ["APIGuardPlugin"]),
    .plugin(name: "QualityGuardPlugin", targets: ["QualityGuardPlugin"]),
    .plugin(name: "ChangeGuardPlugin", targets: ["ChangeGuardPlugin"]),
  ],
  targets: [
    // MARK: - CLI Executables

    .executableTarget(
      name: "APIGuardCLI",
      path: "Sources/APIGuardCLI"
    ),
    .executableTarget(
      name: "QualityGuardCLI",
      path: "Sources/QualityGuardCLI"
    ),
    .executableTarget(
      name: "ChangeGuardCLI",
      path: "Sources/ChangeGuardCLI"
    ),

    // MARK: - SwiftPM Plugins

    .plugin(
      name: "APIGuardPlugin",
      capability: .command(
        intent: .custom(
          verb: "api-guard",
          description: "Check for breaking API changes against baseline"
        ),
        permissions: [
          .writeToPackageDirectory(reason: "Updates API baseline snapshots in api-baseline/")
        ]
      ),
      dependencies: ["APIGuardCLI"],
      path: "Plugins/APIGuardPlugin"
    ),
    .plugin(
      name: "QualityGuardPlugin",
      capability: .command(
        intent: .custom(
          verb: "quality-guard",
          description: "Prevent test deletions and coverage drops"
        ),
        permissions: [
          .writeToPackageDirectory(reason: "Updates coverage baseline file")
        ]
      ),
      dependencies: ["QualityGuardCLI"],
      path: "Plugins/QualityGuardPlugin"
    ),
    .plugin(
      name: "ChangeGuardPlugin",
      capability: .command(
        intent: .custom(
          verb: "change-guard",
          description: "Enforce minimal diffs (file count, LOC, whitespace)"
        ),
        permissions: []
      ),
      dependencies: ["ChangeGuardCLI"],
      path: "Plugins/ChangeGuardPlugin"
    ),

    // MARK: - Tests

    .testTarget(
      name: "GuardTests",
      path: "Tests/GuardTests"
    ),
  ]
)
