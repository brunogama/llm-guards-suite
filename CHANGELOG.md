# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.0.3] - 2026-02-03

### Fixed
- Plugins now use current working directory instead of `context.package.directoryURL`
  - This fixes config file lookup when using guards as a dependency package
  - Previously plugins looked for config in the dependency's directory, not the consumer's

## [0.0.2] - 2026-02-03

### Fixed
- Executable product names now match target names for proper SPM plugin tool lookup
  - Products: `APIGuardCLI`, `QualityGuardCLI`, `ChangeGuardCLI`
  - Run via: `swift run APIGuardCLI`, `swift run QualityGuardCLI`, `swift run ChangeGuardCLI`

## [0.0.1] - 2026-02-03

### Fixed
- Plugin tool lookup now uses target names (`APIGuardCLI`, `QualityGuardCLI`, `ChangeGuardCLI`)
  instead of product names, fixing plugin usage when consumed as a dependency package

## [0.0.0] - 2026-02-03

### Added
- **QualityGuard**: Test deletion prevention tool
  - XCTest function detection (`func testSomething()`)
  - Swift Testing support (`@Test`, `@Suite`)
  - Coverage drop detection (optional)
  - Configurable thresholds
  - Environment variable bypass
- **ChangeGuard**: Diff size enforcement tool
  - File count limits
  - Line count limits
  - Whitespace ratio detection (formatter storm prevention)
  - Configurable pathspecs
- **APIGuard**: Public API stability tool
  - Symbol graph diffing
  - Semver mode (breaking changes only)
  - Strict mode (any API changes)
  - Baseline snapshot management
- SwiftPM command plugins for all three tools
- CLI executables with `--help` support
- Process timeout handling (60s default)
- Separate stdout/stderr forwarding
- Unit tests for test pattern detection
- Example configuration files
- GitHub Actions CI workflow
- Pre-commit hook scripts
- Comprehensive documentation

### Infrastructure
- Swift 6.0 support
- macOS 13.0+ platform requirement
- MIT License

[Unreleased]: https://github.com/brunogama/llm-guards-suite/compare/v0.0.3...HEAD
[0.0.3]: https://github.com/brunogama/llm-guards-suite/compare/v0.0.2...v0.0.3
[0.0.2]: https://github.com/brunogama/llm-guards-suite/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/brunogama/llm-guards-suite/compare/v0.0.0...v0.0.1
[0.0.0]: https://github.com/brunogama/llm-guards-suite/releases/tag/v0.0.0
