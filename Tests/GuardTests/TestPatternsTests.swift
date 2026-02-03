import Foundation
import Testing

// MARK: - Test Pattern Detection Tests

/// Tests for QualityGuard's test detection patterns.
/// Verifies correct detection of both XCTest and Swift Testing frameworks.
@Suite("TestPatterns Detection")
struct TestPatternsTests {

  // MARK: - XCTest Pattern Tests

  @Test("XCTest function: func testSomething()")
  func xctestBasicFunction() {
    let line = "  func testSomething() {"
    #expect(isTestFuncLine(line))
  }

  @Test("XCTest function with numbers: func test123Example()")
  func xctestFunctionWithNumbers() {
    let line = "  func test123Example() {"
    #expect(isTestFuncLine(line))
  }

  @Test("XCTest function with underscores: func test_some_thing()")
  func xctestFunctionWithUnderscores() {
    let line = "  func test_some_thing() {"
    #expect(isTestFuncLine(line))
  }

  @Test("XCTest async function: func testAsync() async")
  func xctestAsyncFunction() {
    let line = "  func testAsync() async throws {"
    #expect(isTestFuncLine(line))
  }

  // MARK: - Swift Testing Pattern Tests

  @Test("Swift Testing: @Test func something()")
  func swiftTestingBasic() {
    let line = "  @Test func something() {"
    #expect(isTestFuncLine(line))
  }

  @Test("Swift Testing with name: @Test(\"Display name\") func something()")
  func swiftTestingWithDisplayName() {
    let line = #"  @Test("Display name") func something() {"#
    #expect(isTestFuncLine(line))
  }

  @Test("Swift Testing with arguments: @Test(arguments: [1,2,3])")
  func swiftTestingWithArguments() {
    let line = "  @Test(arguments: [1, 2, 3]) func parameterized(value: Int) {"
    #expect(isTestFuncLine(line))
  }

  @Test("Swift Testing @Suite: @Suite struct MyTests")
  func swiftTestingSuiteBasic() {
    let line = "  @Suite struct MyTests {"
    #expect(isTestSuiteLine(line))
  }

  @Test("Swift Testing @Suite with name: @Suite(\"Suite name\")")
  func swiftTestingSuiteWithName() {
    let line = #"  @Suite("Suite name") struct MyTests {"#
    #expect(isTestSuiteLine(line))
  }

  // MARK: - Non-Test Functions (Should Not Match)

  @Test("Non-test function: func helperMethod()")
  func nonTestHelper() {
    let line = "  func helperMethod() {"
    #expect(!isTestFuncLine(line))
  }

  @Test("Non-test function with test substring: func getTestData()")
  func nonTestWithTestSubstring() {
    let line = "  func getTestData() {"
    #expect(!isTestFuncLine(line))
  }

  @Test("Comment containing test func: // func testSomething")
  func commentedTestFunc() {
    // This is tricky - the regex will match even in comments
    // but QualityGuard filters for lines starting with "-" in diffs
    let line = "  // func testSomething()"
    // The regex still matches - filtering happens at diff level
    #expect(isTestFuncLine(line))
  }

  @Test("Property with test prefix: var testValue = 1")
  func propertyWithTestPrefix() {
    let line = "  var testValue = 1"
    #expect(!isTestFuncLine(line))
  }

  // MARK: - Helpers (duplicated from QualityGuardCLI for testing)

  /// XCTest pattern: `func testSomething()`
  private let xctestFunc = #"\bfunc\s+test[A-Za-z0-9_]+"#

  /// Swift Testing pattern: `@Test func something()` or `@Test("name") func something()`
  private let swiftTestingFunc = #"@Test\s*(\([^)]*\))?\s*func\s+[A-Za-z0-9_]+"#

  /// Swift Testing suite: `@Suite` or `@Suite("name")`
  private let swiftTestingSuite = #"@Suite\s*(\([^)]*\))?"#

  private func isTestFuncLine(_ line: String) -> Bool {
    line.range(of: xctestFunc, options: .regularExpression) != nil ||
    line.range(of: swiftTestingFunc, options: .regularExpression) != nil
  }

  private func isTestSuiteLine(_ line: String) -> Bool {
    line.range(of: swiftTestingSuite, options: .regularExpression) != nil
  }
}

// MARK: - Config Validation Tests

@Suite("Config Validation")
struct ConfigValidationTests {

  @Test("Valid QualityGuard config parses correctly")
  func validQualityGuardConfig() throws {
    let json = """
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
    """
    let data = json.data(using: .utf8)!
    let config = try JSONDecoder().decode(QualityGuardConfig.self, from: data)

    #expect(config.range == "origin/main...HEAD")
    #expect(config.testsPathspec == "Tests/**")
    #expect(config.maxDeletedTestFiles == 0)
    #expect(config.maxDeletedTestLines == 0)
    #expect(config.maxDeletedTestFuncs == 0)
    #expect(config.allowEnvVar == "ALLOW_TEST_DELETIONS")
    #expect(config.coverage.enabled == false)
    #expect(config.coverage.baselineFile == "coverage-baseline.txt")
    #expect(config.coverage.minAbsolute == 0.0)
    #expect(config.coverage.maxDrop == 0.0)
    #expect(config.coverage.command == "echo 0.0")
  }

  @Test("Valid ChangeGuard config parses correctly")
  func validChangeGuardConfig() throws {
    let json = """
    {
      "range": "origin/main...HEAD",
      "pathspecs": ["Sources/**", "Tests/**"],
      "maxFilesChanged": 10,
      "maxTotalChangedLines": 400,
      "maxWhitespaceRatio": 0.3,
      "allowEnvVar": "ALLOW_LARGE_DIFF"
    }
    """
    let data = json.data(using: .utf8)!
    let config = try JSONDecoder().decode(ChangeGuardConfig.self, from: data)

    #expect(config.range == "origin/main...HEAD")
    #expect(config.pathspecs == ["Sources/**", "Tests/**"])
    #expect(config.maxFilesChanged == 10)
    #expect(config.maxTotalChangedLines == 400)
    #expect(config.maxWhitespaceRatio == 0.3)
    #expect(config.allowEnvVar == "ALLOW_LARGE_DIFF")
  }
}

// MARK: - Config Types (duplicated for test target)

struct QualityGuardConfig: Decodable {
  struct Coverage: Decodable {
    let enabled: Bool
    let baselineFile: String
    let minAbsolute: Double
    let maxDrop: Double
    let command: String
  }

  let range: String
  let testsPathspec: String
  let maxDeletedTestFiles: Int
  let maxDeletedTestLines: Int
  let maxDeletedTestFuncs: Int
  let allowEnvVar: String
  let coverage: Coverage
}

struct ChangeGuardConfig: Decodable {
  let range: String
  let pathspecs: [String]
  let maxFilesChanged: Int
  let maxTotalChangedLines: Int
  let maxWhitespaceRatio: Double
  let allowEnvVar: String
}
