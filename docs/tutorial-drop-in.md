# Tutorial: Drop-in Installation

This tutorial shows how to integrate LLM Guards Suite directly into your existing Swift package without adding it as a dependency.

## When to Use Drop-in

Use drop-in installation when:
- You want to customize the tools
- You prefer not to add external dependencies
- You need to modify the detection patterns
- You're in an air-gapped environment

## Step 1: Copy Files

Copy these directories and files to your package root:

```bash
# From llm-guards-suite repository
cp -r Sources/APIGuardCLI your-package/Sources/
cp -r Sources/QualityGuardCLI your-package/Sources/
cp -r Sources/ChangeGuardCLI your-package/Sources/
cp -r Plugins/ your-package/
cp -r Scripts/ your-package/
cp .apiguard.json your-package/
cp .qualityguard.json your-package/
cp .changeguard.json your-package/
```

## Step 2: Update Package.swift

Add the following to your `Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "YourPackage",
    platforms: [.macOS(.v13)],
    products: [
        // Your existing products...

        // Guard executables (optional - plugins use these internally)
        .executable(name: "apiguard", targets: ["APIGuardCLI"]),
        .executable(name: "qualityguard", targets: ["QualityGuardCLI"]),
        .executable(name: "changeguard", targets: ["ChangeGuardCLI"]),

        // Guard plugins
        .plugin(name: "APIGuardPlugin", targets: ["APIGuardPlugin"]),
        .plugin(name: "QualityGuardPlugin", targets: ["QualityGuardPlugin"]),
        .plugin(name: "ChangeGuardPlugin", targets: ["ChangeGuardPlugin"]),
    ],
    targets: [
        // Your existing targets...

        // Guard CLI executables
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

        // Guard plugins
        .plugin(
            name: "APIGuardPlugin",
            capability: .command(
                intent: .custom(
                    verb: "api-guard",
                    description: "Check for breaking API changes"
                ),
                permissions: [
                    .writeToPackageDirectory(reason: "Updates API baseline snapshots")
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
                    .writeToPackageDirectory(reason: "Updates coverage baseline")
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
                    description: "Enforce minimal diffs"
                ),
                permissions: []
            ),
            dependencies: ["ChangeGuardCLI"],
            path: "Plugins/ChangeGuardPlugin"
        ),
    ]
)
```

## Step 3: Configure for Your Project

Edit the configuration files for your specific needs:

### .qualityguard.json

```json
{
  "range": "origin/main...HEAD",
  "testsPathspec": "Tests/**",
  "maxDeletedTestFiles": 0,
  "maxDeletedTestLines": 0,
  "maxDeletedTestFuncs": 0,
  "allowEnvVar": "ALLOW_TEST_DELETIONS",
  "coverage": {
    "enabled": false,
    "baselineFile": "coverage-baseline.txt",
    "minAbsolute": 0.0,
    "maxDrop": 0.0,
    "command": "echo 0.0"
  }
}
```

### .changeguard.json

```json
{
  "range": "origin/main...HEAD",
  "pathspecs": ["Sources/**", "Tests/**", "Package.swift"],
  "maxFilesChanged": 10,
  "maxTotalChangedLines": 400,
  "maxWhitespaceRatio": 0.3,
  "allowEnvVar": "ALLOW_LARGE_DIFF"
}
```

### .apiguard.json

```json
{
  "targets": ["YourPublicTarget"],
  "mode": "semver",
  "baselineDir": "api-baseline",
  "outputDir": ".build/apiguard",
  "failOnAdditions": false
}
```

## Step 4: Initialize and Test

```bash
# Build to verify integration
swift build

# Initialize API baseline
swift run APIGuardCLI --update
git add api-baseline/
git commit -m "Add API baseline"

# Test all guards
swift run QualityGuardCLI
swift run ChangeGuardCLI
swift run APIGuardCLI
```

## Customization

### Adding Custom Test Patterns

Edit `Sources/QualityGuardCLI/main.swift` to add custom patterns:

```swift
enum TestPatterns {
  static let xctestFunc = #"\bfunc\s+test[A-Za-z0-9_]+"#
  static let swiftTestingFunc = #"@Test\s*(\([^)]*\))?\s*func\s+[A-Za-z0-9_]+"#
  static let swiftTestingSuite = #"@Suite\s*(\([^)]*\))?"#

  // Add your custom patterns here
  static let customPattern = #"your_regex_pattern"#
}
```

### Modifying Thresholds Dynamically

You can override thresholds via environment variables or command-line arguments as needed in the CLI source files.

## Keeping Up to Date

When updating from the upstream repository:

1. Check the [CHANGELOG](../CHANGELOG.md) for breaking changes
2. Copy updated source files
3. Review and merge any configuration changes
4. Run tests to verify compatibility
