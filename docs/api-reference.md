# API Reference

Complete configuration reference for all LLM Guards Suite tools.

## QualityGuard

### Configuration File: `.qualityguard.json`

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `range` | string | `"origin/main...HEAD"` | Git range for diff analysis |
| `testsPathspec` | string | `"Tests/**"` | Glob pattern for test files |
| `maxDeletedTestFiles` | integer | `0` | Maximum allowed deleted test files |
| `maxDeletedTestLines` | integer | `0` | Maximum allowed deleted test lines |
| `maxDeletedTestFuncs` | integer | `0` | Maximum allowed deleted test functions |
| `allowEnvVar` | string | `"ALLOW_TEST_DELETIONS"` | Environment variable to bypass checks |
| `coverage` | object | see below | Coverage tracking configuration |

### Coverage Configuration

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `coverage.enabled` | boolean | `false` | Enable coverage tracking |
| `coverage.baselineFile` | string | `"coverage-baseline.txt"` | Path to baseline file |
| `coverage.minAbsolute` | number | `0.0` | Minimum absolute coverage (0-100) |
| `coverage.maxDrop` | number | `0.0` | Maximum allowed coverage drop (0-100) |
| `coverage.command` | string | `"echo 0.0"` | Shell command to get current coverage |

### CLI Usage

```bash
# Using swift run
swift run QualityGuardCLI [OPTIONS]

# Using swift package plugin
swift package quality-guard [-- OPTIONS]
```

### Options

| Option | Description |
|--------|-------------|
| `--config <path>` | Path to configuration file (default: `.qualityguard.json`) |
| `--range <range>` | Git range to analyze (overrides config) |
| `--help`, `-h` | Show help message |

### Exit Codes

| Code | Meaning |
|------|---------|
| `0` | All checks passed |
| `1` | Violations detected |
| `2` | Configuration or runtime error |

### Detected Patterns

QualityGuard detects the following test patterns:

**XCTest:**
- `func testSomething()` - Functions prefixed with `test`

**Swift Testing:**
- `@Test func something()` - Functions with `@Test` attribute
- `@Test("Display name") func something()` - Functions with named `@Test`
- `@Suite struct MyTests` - Test suites with `@Suite` attribute

---

## ChangeGuard

### Configuration File: `.changeguard.json`

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `range` | string | `"origin/main...HEAD"` | Git range for diff analysis |
| `pathspecs` | array | `["Sources/**", "Tests/**", "Package.swift"]` | Paths to include in analysis |
| `maxFilesChanged` | integer | `10` | Maximum allowed changed files |
| `maxTotalChangedLines` | integer | `400` | Maximum total changed lines |
| `maxWhitespaceRatio` | number | `0.3` | Maximum whitespace-only change ratio (0-1) |
| `allowEnvVar` | string | `"ALLOW_LARGE_DIFF"` | Environment variable to bypass checks |

### Pathspec Syntax

Standard git pathspec syntax is supported:

```json
{
  "pathspecs": [
    "Sources/**",
    "Tests/**",
    "Package.swift",
    ":(exclude)Sources/Generated/**",
    ":(exclude)**/*.generated.swift"
  ]
}
```

### CLI Usage

```bash
# Using swift run
swift run ChangeGuardCLI [OPTIONS]

# Using swift package plugin
swift package change-guard [-- OPTIONS]
```

### Options

| Option | Description |
|--------|-------------|
| `--config <path>` | Path to configuration file (default: `.changeguard.json`) |
| `--range <range>` | Git range to analyze (overrides config) |
| `--help`, `-h` | Show help message |

### Exit Codes

| Code | Meaning |
|------|---------|
| `0` | All checks passed |
| `1` | Violations detected |
| `2` | Configuration or runtime error |

---

## APIGuard

### Configuration File: `.apiguard.json`

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `targets` | array | `[]` | Swift targets to analyze (required) |
| `mode` | string | `"semver"` | Check mode: `"semver"` or `"strict"` |
| `baselineDir` | string | `"api-baseline"` | Directory for baseline snapshots |
| `outputDir` | string | `".build/apiguard"` | Directory for current snapshots |
| `failOnAdditions` | boolean | `false` | Fail if new public APIs are added |

### Modes

**Semver Mode (`"semver"`):**
- Allows additions (minor version bump)
- Blocks removals and signature changes (breaking)

**Strict Mode (`"strict"`):**
- Blocks all changes including additions
- Use for stable/locked APIs

### CLI Usage

```bash
# Using swift run
swift run APIGuardCLI [OPTIONS]

# Using swift package plugin
swift package api-guard [-- OPTIONS]
```

### Options

| Option | Description |
|--------|-------------|
| `--config <path>` | Path to configuration file (default: `.apiguard.json`) |
| `--update` | Update baseline snapshots instead of comparing |
| `--help`, `-h` | Show help message |

### Exit Codes

| Code | Meaning |
|------|---------|
| `0` | No breaking changes detected |
| `1` | Breaking changes detected |
| `2` | Configuration or runtime error |

### Symbol Graph

APIGuard uses Swift's symbol graph extraction:

```bash
swift symbolgraph-extract -target <target> -output-dir <dir>
```

The generated JSON contains all public API symbols which are compared against the baseline.

---

## Environment Variables

### Bypass Variables

| Variable | Guard | Effect |
|----------|-------|--------|
| `ALLOW_TEST_DELETIONS=1` | QualityGuard | Skip test deletion checks |
| `ALLOW_LARGE_DIFF=1` | ChangeGuard | Skip diff size checks |

### Debug Variables

| Variable | Effect |
|----------|--------|
| `DEBUG_GUARDS=1` | Enable verbose debug output |

---

## Plugin Capabilities

All guards are available as Swift Package Manager plugins:

| Plugin | Verb | Permissions |
|--------|------|-------------|
| QualityGuardPlugin | `quality-guard` | Write (coverage baseline) |
| ChangeGuardPlugin | `change-guard` | None |
| APIGuardPlugin | `api-guard` | Write (API baseline) |

### Plugin Invocation

```bash
# Standard invocation
swift package <verb>

# With arguments (note the --)
swift package <verb> -- --config custom.json

# Example
swift package quality-guard -- --range "HEAD~5...HEAD"
```
