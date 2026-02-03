# Contributing to LLM Guards Suite

Thank you for your interest in contributing to LLM Guards Suite.

## Development Setup

### Prerequisites

- macOS 13.0 or later
- Swift 6.0 or later
- Git

### Getting Started

```bash
# Clone the repository
git clone https://github.com/brunogama/llm-guards-suite.git
cd llm-guards-suite

# Build
swift build

# Run tests
swift test

# Run a specific guard
swift run QualityGuardCLI --help
```

## Code Style

### Swift Guidelines

- Use Swift 6 strict concurrency
- No force unwraps (`!`) or force casts (`as!`)
- No `fatalError`, `precondition`, or `assert` in production code
- Document public APIs with `///` comments
- Keep files under 400 lines
- Keep functions under 80 lines

### Formatting

This project uses swift-format. Format your code before committing:

```bash
swift-format -i Sources/**/*.swift
```

## Pull Request Process

### Before Submitting

1. **Run all checks:**
   ```bash
   swift build
   swift test
   ```

2. **Test your changes locally:**
   ```bash
   swift run QualityGuardCLI
   swift run ChangeGuardCLI
   swift run APIGuardCLI
   ```

3. **Update documentation** if you changed behavior

4. **Update CHANGELOG.md** under `[Unreleased]`

### PR Guidelines

- Keep PRs focused and small
- Write clear commit messages
- Reference issues if applicable
- Ensure CI passes

### Commit Messages

Use conventional commits:

```
feat: add support for Swift Testing @Suite attribute
fix: handle empty diff in ChangeGuard
docs: update API reference for coverage options
test: add property-based tests for pattern matching
refactor: extract process runner to shared module
```

## Testing

### Running Tests

```bash
# All tests
swift test

# Specific test
swift test --filter TestPatternsTests
```

### Writing Tests

Use Swift Testing framework:

```swift
import Testing

@Suite("My Feature Tests")
struct MyFeatureTests {
    @Test("description of what is being tested")
    func testCase() {
        #expect(actual == expected)
    }
}
```

### Test Organization

```
Tests/GuardTests/
├── QualityGuardTests.swift    # QualityGuard unit tests
├── ChangeGuardTests.swift     # ChangeGuard unit tests
├── APIGuardTests.swift        # APIGuard unit tests
├── TestPatternsTests.swift    # Pattern detection tests
└── IntegrationTests.swift     # End-to-end tests
```

## Adding New Features

### New Detection Patterns

To add new test patterns to QualityGuard:

1. Add the regex to `TestPatterns` enum in `QualityGuardCLI/main.swift`
2. Update the detection functions
3. Add tests in `TestPatternsTests.swift`
4. Update documentation

### New Configuration Options

1. Add the field to the `Config` struct
2. Provide a sensible default
3. Add validation if needed
4. Update the config templates
5. Document in API reference

## Reporting Issues

### Bug Reports

Include:
- Swift version (`swift --version`)
- macOS version
- Steps to reproduce
- Expected vs actual behavior
- Relevant configuration

### Feature Requests

Describe:
- The use case
- Proposed solution
- Alternatives considered

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
