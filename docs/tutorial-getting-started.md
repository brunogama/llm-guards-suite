# Tutorial: Getting Started with LLM Guards Suite

This tutorial walks you through setting up LLM Guards Suite in a new or existing Swift project.

## Prerequisites

- macOS 13.0 or later
- Swift 6.0 or later
- Git repository with history

## Step 1: Add the Package

### Option A: Swift Package Manager

Add to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/brunogama/llm-guards-suite.git", from: "0.1.0")
]
```

### Option B: Drop-in Installation

See [Tutorial: Drop-in Installation](tutorial-drop-in.md).

## Step 2: Create Configuration Files

Create the three configuration files in your project root:

### QualityGuard Configuration

```bash
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
```

### ChangeGuard Configuration

```bash
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
```

### APIGuard Configuration

```bash
cat > .apiguard.json << 'EOF'
{
  "targets": ["YourLibraryTarget"],
  "mode": "semver",
  "baselineDir": "api-baseline",
  "outputDir": ".build/apiguard",
  "failOnAdditions": false
}
EOF
```

Replace `YourLibraryTarget` with your actual public library target name.

## Step 3: Initialize API Baseline

For APIGuard to work, you need to create an initial baseline:

```bash
swift run APIGuardCLI --update
git add api-baseline/
git commit -m "Add API baseline"
```

## Step 4: Test the Guards

Run each guard to verify they work:

```bash
# Test QualityGuard
swift run QualityGuardCLI --help
swift run QualityGuardCLI

# Test ChangeGuard
swift run ChangeGuardCLI --help
swift run ChangeGuardCLI

# Test APIGuard
swift run APIGuardCLI --help
swift run APIGuardCLI
```

## Step 5: Add to CI

Create `.github/workflows/guards.yml`:

```yaml
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

      - name: Select base range
        id: range
        run: |
          if [ "${{ github.event_name }}" = "pull_request" ]; then
            echo "RANGE=origin/${{ github.base_ref }}...HEAD" >> $GITHUB_OUTPUT
          else
            echo "RANGE=origin/main...HEAD" >> $GITHUB_OUTPUT
          fi

      - name: QualityGuard
        run: swift package quality-guard -- --range "${{ steps.range.outputs.RANGE }}"

      - name: ChangeGuard
        run: swift package change-guard -- --range "${{ steps.range.outputs.RANGE }}"

      - name: APIGuard
        run: swift package api-guard
```

## Step 6: Install Local Hooks (Optional)

For faster feedback during development:

```bash
chmod +x Scripts/*.sh
./Scripts/install-git-hooks.sh
```

## Next Steps

- [Tutorial: Custom Configurations](tutorial-custom-configs.md) - Fine-tune thresholds
- [Tutorial: CI Integration](tutorial-ci-integration.md) - Advanced CI setups
- [API Reference](api-reference.md) - Complete configuration options
