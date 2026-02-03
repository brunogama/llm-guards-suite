# Tutorial: Custom Configurations

This tutorial covers advanced configuration options for each guard.

## QualityGuard Configuration

### Zero-Tolerance Mode (Recommended)

For maximum protection against test regressions:

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

### Lenient Mode (For Large Refactors)

When you expect some test restructuring:

```json
{
  "range": "origin/main...HEAD",
  "testsPathspec": "Tests/**",
  "maxDeletedTestFiles": 2,
  "maxDeletedTestLines": 50,
  "maxDeletedTestFuncs": 5,
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

### With Coverage Tracking

Enable coverage tracking with your coverage tool:

```json
{
  "range": "origin/main...HEAD",
  "testsPathspec": "Tests/**",
  "maxDeletedTestFiles": 0,
  "maxDeletedTestLines": 0,
  "maxDeletedTestFuncs": 0,
  "allowEnvVar": "ALLOW_TEST_DELETIONS",
  "coverage": {
    "enabled": true,
    "baselineFile": "coverage-baseline.txt",
    "minAbsolute": 80.0,
    "maxDrop": 2.0,
    "command": "xcrun llvm-cov report .build/debug/YourPackagePackageTests.xctest/Contents/MacOS/YourPackagePackageTests --instr-profile .build/debug/codecov/default.profdata | tail -1 | awk '{print $4}' | tr -d '%'"
  }
}
```

### Multiple Test Directories

For monorepos with multiple test locations:

```json
{
  "range": "origin/main...HEAD",
  "testsPathspec": "{Tests,IntegrationTests,E2ETests}/**",
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

## ChangeGuard Configuration

### Strict Mode (Small PRs)

For teams practicing small, focused PRs:

```json
{
  "range": "origin/main...HEAD",
  "pathspecs": ["Sources/**", "Tests/**", "Package.swift"],
  "maxFilesChanged": 5,
  "maxTotalChangedLines": 200,
  "maxWhitespaceRatio": 0.2,
  "allowEnvVar": "ALLOW_LARGE_DIFF"
}
```

### Standard Mode

Balanced settings for most teams:

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

### Lenient Mode (Feature Branches)

For larger feature development:

```json
{
  "range": "origin/main...HEAD",
  "pathspecs": ["Sources/**", "Tests/**", "Package.swift"],
  "maxFilesChanged": 25,
  "maxTotalChangedLines": 1000,
  "maxWhitespaceRatio": 0.4,
  "allowEnvVar": "ALLOW_LARGE_DIFF"
}
```

### Excluding Generated Files

Exclude auto-generated code from checks:

```json
{
  "range": "origin/main...HEAD",
  "pathspecs": [
    "Sources/**",
    "Tests/**",
    "Package.swift",
    ":(exclude)Sources/Generated/**",
    ":(exclude)**/*.generated.swift"
  ],
  "maxFilesChanged": 10,
  "maxTotalChangedLines": 400,
  "maxWhitespaceRatio": 0.3,
  "allowEnvVar": "ALLOW_LARGE_DIFF"
}
```

## APIGuard Configuration

### Semver Mode (Recommended)

Allow additions, block breaking changes:

```json
{
  "targets": ["MyPublicLibrary"],
  "mode": "semver",
  "baselineDir": "api-baseline",
  "outputDir": ".build/apiguard",
  "failOnAdditions": false
}
```

### Strict Mode (Locked API)

Block any API changes (for stable releases):

```json
{
  "targets": ["MyPublicLibrary"],
  "mode": "strict",
  "baselineDir": "api-baseline",
  "outputDir": ".build/apiguard",
  "failOnAdditions": true
}
```

### Multiple Targets

Protect multiple public libraries:

```json
{
  "targets": [
    "CoreLibrary",
    "NetworkingLibrary",
    "UIComponents"
  ],
  "mode": "semver",
  "baselineDir": "api-baseline",
  "outputDir": ".build/apiguard",
  "failOnAdditions": false
}
```

## Environment-Specific Configs

### Development vs Production

Create separate configs for different environments:

```bash
# .qualityguard.json - strict for production
# .qualityguard.dev.json - lenient for development

# Run with specific config
swift run qualityguard --config .qualityguard.dev.json
```

### Config Per Branch

In CI, select config based on branch:

```yaml
- name: Select Config
  id: config
  run: |
    if [ "${{ github.base_ref }}" = "main" ]; then
      echo "config=.qualityguard.json" >> $GITHUB_OUTPUT
    else
      echo "config=.qualityguard.dev.json" >> $GITHUB_OUTPUT
    fi

- name: QualityGuard
  run: swift package quality-guard -- --config "${{ steps.config.outputs.config }}"
```

## Validation

Test your configuration before committing:

```bash
# Validate JSON syntax
cat .qualityguard.json | python3 -m json.tool

# Test with dry run
swift run qualityguard --help
swift run qualityguard  # Check output

# Test bypass
ALLOW_TEST_DELETIONS=1 swift run qualityguard
```
