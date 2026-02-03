# LLM Guards Suite

A Swift Package providing quality gates for LLM-assisted development workflows. Prevent accidental test deletions, breaking API changes, and oversized diffs in your CI/CD pipeline.

[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![CI](https://github.com/brunogama/llm-guards-suite/actions/workflows/ci.yml/badge.svg)](https://github.com/brunogama/llm-guards-suite/actions/workflows/ci.yml)

## Overview

LLM Guards Suite provides three complementary tools to maintain code quality when using AI coding assistants:

| Tool | Purpose | Prevents |
|------|---------|----------|
| **QualityGuard** | Test integrity protection | Accidental test deletions, coverage drops |
| **ChangeGuard** | Diff size enforcement | Oversized PRs, formatter storms |
| **APIGuard** | API stability protection | Breaking public API changes |

## Installation

### Swift Package Manager (Recommended)

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/brunogama/llm-guards-suite.git", from: "0.1.0")
]
```

### Drop-in Integration

Copy the `Sources/`, `Plugins/`, and config files directly into your project. See [Tutorial: Drop-in Installation](docs/tutorial-drop-in.md).

## Quick Start

### 1. Create Configuration Files

```bash
# Create default configs
cat > .qualityguard.json << 'EOF'
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
EOF

cat > .changeguard.json << 'EOF'
{
  "range": "origin/main...HEAD",
  "pathspecs": ["Sources/**", "Tests/**", "Package.swift"],
  "maxFilesChanged": 10,
  "maxTotalChangedLines": 400,
  "maxWhitespaceRatio": 0.3,
  "allowEnvVar": "ALLOW_LARGE_DIFF"
}
EOF

cat > .apiguard.json << 'EOF'
{
  "targets": ["YourPublicTarget"],
  "mode": "semver",
  "baselineDir": "api-baseline",
  "outputDir": ".build/apiguard",
  "failOnAdditions": false
}
EOF
```

### 2. Run Guards

```bash
# Using Swift Package plugins
swift package quality-guard
swift package change-guard
swift package api-guard

# Or run CLIs directly
swift run QualityGuardCLI --help
swift run ChangeGuardCLI --help
swift run APIGuardCLI --help
```

### 3. Add to CI

```yaml
# .github/workflows/guards.yml
name: Guards

on:
  pull_request:
  push:
    branches: [main]

jobs:
  guard:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: QualityGuard
        run: swift package quality-guard

      - name: ChangeGuard
        run: swift package change-guard

      - name: APIGuard
        run: swift package api-guard
```

## Tools

### QualityGuard

Prevents accidental deletion of test code during refactoring or AI-assisted changes.

**Features:**
- Detects XCTest functions (`func testSomething()`)
- Detects Swift Testing functions (`@Test func something()`)
- Detects Swift Testing suites (`@Suite`)
- Optional coverage tracking
- Configurable thresholds

**Configuration:**

| Field | Type | Description |
|-------|------|-------------|
| `range` | string | Git diff range (e.g., `origin/main...HEAD`) |
| `testsPathspec` | string | Glob pattern for test files |
| `maxDeletedTestFiles` | int | Max allowed deleted test files |
| `maxDeletedTestLines` | int | Max allowed deleted test lines |
| `maxDeletedTestFuncs` | int | Max allowed deleted test functions |
| `allowEnvVar` | string | Environment variable to bypass checks |
| `coverage.enabled` | bool | Enable coverage tracking |
| `coverage.baselineFile` | string | Path to coverage baseline |
| `coverage.minAbsolute` | float | Minimum absolute coverage (0-100) |
| `coverage.maxDrop` | float | Maximum coverage drop allowed |
| `coverage.command` | string | Command to get current coverage |

**Bypass:**
```bash
ALLOW_TEST_DELETIONS=1 swift package quality-guard
```

### ChangeGuard

Enforces minimal, focused diffs to prevent sprawling changes.

**Features:**
- File count limits
- Line count limits
- Whitespace ratio detection (catches formatter storms)
- Configurable pathspecs

**Configuration:**

| Field | Type | Description |
|-------|------|-------------|
| `range` | string | Git diff range |
| `pathspecs` | [string] | Glob patterns to include |
| `maxFilesChanged` | int | Max files allowed to change |
| `maxTotalChangedLines` | int | Max total lines (added + deleted) |
| `maxWhitespaceRatio` | float | Max whitespace-only change ratio (0-1) |
| `allowEnvVar` | string | Environment variable to bypass |

**Bypass:**
```bash
ALLOW_LARGE_DIFF=1 swift package change-guard
```

### APIGuard

Prevents breaking changes to public APIs using symbol graph diffing.

**Features:**
- Semver mode (block breaking changes only)
- Strict mode (block any API changes)
- Baseline snapshot management
- Supports public and open access levels

**Configuration:**

| Field | Type | Description |
|-------|------|-------------|
| `targets` | [string] | Swift targets to check |
| `mode` | string | `semver` or `strict` |
| `baselineDir` | string | Directory for baseline snapshots |
| `outputDir` | string | Build output directory |
| `failOnAdditions` | bool | Also fail on API additions |

**Workflow:**
```bash
# First time: create baseline
swift run APIGuardCLI --update

# CI: check against baseline
swift run APIGuardCLI

# After intentional API change
swift run APIGuardCLI --update
git add api-baseline/
git commit -m "Update API baseline"
```

## Pre-commit Hooks

Install hooks using the provided script:

```bash
chmod +x Scripts/*.sh
./Scripts/install-git-hooks.sh
```

Or use [pre-commit](https://pre-commit.com/):

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: quality-guard
        name: QualityGuard
        entry: swift run QualityGuardCLI
        language: system
        pass_filenames: false
        stages: [pre-push]

      - id: change-guard
        name: ChangeGuard
        entry: swift run ChangeGuardCLI
        language: system
        pass_filenames: false
        stages: [pre-push]
```

## Documentation

- [Tutorial: Getting Started](docs/tutorial-getting-started.md)
- [Tutorial: Drop-in Installation](docs/tutorial-drop-in.md)
- [Tutorial: CI Integration](docs/tutorial-ci-integration.md)
- [Tutorial: Custom Configurations](docs/tutorial-custom-configs.md)
- [API Reference](docs/api-reference.md)
- [Examples](examples/)

## Requirements

- macOS 13.0+
- Swift 6.0+
- Git (for diff operations)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `swift test`
5. Submit a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release history.
