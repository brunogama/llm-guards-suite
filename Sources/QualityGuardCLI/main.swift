import Foundation

// MARK: - Configuration

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

// MARK: - Error Types

enum QGError: Error, CustomStringConvertible {
  case invalidArguments(String)
  case configNotFound(String)
  case configDecodeFailed(String)
  case gitFailed(Int32, String)
  case violation(String)

  var description: String {
    switch self {
    case .invalidArguments(let s): return s
    case .configNotFound(let p): return "Config not found: \(p)"
    case .configDecodeFailed(let s): return "Config decode failed: \(s)"
    case .gitFailed(let code, let out): return "git failed (\(code))\n\(out)"
    case .violation(let s): return s
    }
  }
}

// MARK: - Test Detection Patterns

/// Patterns for detecting test functions in Swift code.
/// Supports both XCTest (`func testXxx`) and Swift Testing (`@Test func xxx`).
enum TestPatterns {
  /// XCTest pattern: `func testSomething()`
  static let xctestFunc = #"\bfunc\s+test[A-Za-z0-9_]+"#

  /// Swift Testing pattern: `@Test func something()` or `@Test("name") func something()`
  static let swiftTestingFunc = #"@Test\s*(\([^)]*\))?\s*func\s+[A-Za-z0-9_]+"#

  /// Swift Testing suite: `@Suite` or `@Suite("name")`
  static let swiftTestingSuite = #"@Suite\s*(\([^)]*\))?"#

  /// Combined pattern matching any test function declaration
  static var anyTestFunc: String {
    "(\(xctestFunc)|\(swiftTestingFunc))"
  }

  /// Check if a line contains a test function declaration
  static func isTestFuncLine(_ line: some StringProtocol) -> Bool {
    line.range(of: xctestFunc, options: .regularExpression) != nil ||
    line.range(of: swiftTestingFunc, options: .regularExpression) != nil
  }

  /// Check if a line contains a test suite declaration
  static func isTestSuiteLine(_ line: some StringProtocol) -> Bool {
    line.range(of: swiftTestingSuite, options: .regularExpression) != nil
  }
}

// MARK: - Main Entry Point

@main
enum QualityGuard {
  static let version = "1.1.0"

  static func main() {
    do {
      try run()
    } catch let e as QGError {
      fputs(e.description + "\n", stderr)
      exit(1)
    } catch {
      fputs("qualityguard error: \(error)\n", stderr)
      exit(1)
    }
  }

  static func run() throws {
    let args = CommandLine.arguments
    var configPath: String?
    var rangeOverride: String?

    var i = 1
    while i < args.count {
      switch args[i] {
      case "--help", "-h":
        printHelp()
        return
      case "--version", "-v":
        print("qualityguard \(version)")
        return
      case "--config":
        i += 1
        guard i < args.count else { throw QGError.invalidArguments("Missing value for --config") }
        configPath = args[i]
      case "--range":
        i += 1
        guard i < args.count else { throw QGError.invalidArguments("Missing value for --range") }
        rangeOverride = args[i]
      default:
        break
      }
      i += 1
    }

    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let resolvedConfig = configPath ?? ".qualityguard.json"
    // Handle both absolute and relative paths
    let cfgURL: URL
    if resolvedConfig.hasPrefix("/") {
      cfgURL = URL(fileURLWithPath: resolvedConfig)
    } else {
      cfgURL = cwd.appendingPathComponent(resolvedConfig)
    }

    guard FileManager.default.fileExists(atPath: cfgURL.path) else {
      throw QGError.configNotFound(cfgURL.path)
    }

    let cfgData = try Data(contentsOf: cfgURL)
    let cfg: QualityGuardConfig
    do {
      cfg = try JSONDecoder().decode(QualityGuardConfig.self, from: cfgData)
    } catch {
      throw QGError.configDecodeFailed(error.localizedDescription)
    }

    if let allow = ProcessInfo.processInfo.environment[cfg.allowEnvVar], allow == "1" {
      print("qualityguard: bypassed via \(cfg.allowEnvVar)=1")
      return
    }

    let range = rangeOverride ?? cfg.range
    let testsSpec = cfg.testsPathspec

    // 1) Deleted test files
    let nameStatus = try git(["diff", "--name-status", range, "--", testsSpec])
    let deletedFiles = nameStatus
      .split(separator: "\n")
      .compactMap { line -> String? in
        // Format: D<TAB>path
        if line.hasPrefix("D\t") {
          return String(line.dropFirst(2))
        }
        return nil
      }

    if deletedFiles.count > cfg.maxDeletedTestFiles {
      var msg = "FAIL: Deleted test files: \(deletedFiles.count) (max \(cfg.maxDeletedTestFiles))\n"
      for f in deletedFiles.prefix(50) { msg += "  \(f)\n" }
      throw QGError.violation(msg)
    }

    // 2) Deleted lines in Tests/**
    let numstat = try git(["diff", "--numstat", range, "--", testsSpec])
    var deletedLines = 0
    for line in numstat.split(separator: "\n") {
      // Format: <added>\t<deleted>\t<path>
      let parts = line.split(separator: "\t")
      if parts.count >= 2 {
        let del = Int(parts[1]) ?? 0
        deletedLines += del
      }
    }

    if deletedLines > cfg.maxDeletedTestLines {
      throw QGError.violation("FAIL: Deleted test lines: \(deletedLines) (max \(cfg.maxDeletedTestLines))")
    }

    // 3) Deleted test funcs (supports both XCTest and Swift Testing)
    let testDiff = try git(["diff", range, "--", testsSpec])
    let deletedTestFuncLines = testDiff
      .split(separator: "\n")
      .filter { line in
        // Only consider removed lines (starting with -)
        guard line.hasPrefix("-") else { return false }
        return TestPatterns.isTestFuncLine(line)
      }

    // Also check for deleted @Suite declarations
    let deletedSuiteLines = testDiff
      .split(separator: "\n")
      .filter { line in
        guard line.hasPrefix("-") else { return false }
        return TestPatterns.isTestSuiteLine(line)
      }

    let totalDeletedTestDeclarations = deletedTestFuncLines.count + deletedSuiteLines.count

    if totalDeletedTestDeclarations > cfg.maxDeletedTestFuncs {
      var msg = "FAIL: Deleted test declarations: \(totalDeletedTestDeclarations) (max \(cfg.maxDeletedTestFuncs))\n"
      msg += "  Test functions: \(deletedTestFuncLines.count)\n"
      msg += "  Test suites: \(deletedSuiteLines.count)\n"
      for l in deletedTestFuncLines.prefix(25) { msg += "  \(l)\n" }
      for l in deletedSuiteLines.prefix(25) { msg += "  \(l)\n" }
      throw QGError.violation(msg)
    }

    // 4) Optional coverage guard
    if cfg.coverage.enabled {
      let baselineURL = cwd.appendingPathComponent(cfg.coverage.baselineFile)
      guard FileManager.default.fileExists(atPath: baselineURL.path) else {
        throw QGError.violation("FAIL: Coverage baseline missing: \(cfg.coverage.baselineFile)")
      }
      let baselineText = (try String(contentsOf: baselineURL, encoding: .utf8)).trimmingCharacters(in: .whitespacesAndNewlines)
      let baseline = Double(baselineText) ?? 0.0

      // Run configured command (shell) and parse a single float from stdout.
      let out = try sh(cfg.coverage.command)
        .trimmingCharacters(in: .whitespacesAndNewlines)

      guard let current = Double(out) else {
        throw QGError.violation("FAIL: Coverage command did not output a single float. Output was:\n\(out)")
      }

      if current < cfg.coverage.minAbsolute {
        throw QGError.violation("FAIL: Coverage \(current) below minimum \(cfg.coverage.minAbsolute)")
      }

      let drop = baseline - current
      if drop > cfg.coverage.maxDrop {
        throw QGError.violation("FAIL: Coverage dropped by \(drop) (baseline \(baseline) -> current \(current)), max drop \(cfg.coverage.maxDrop)")
      }

      print("coverage-guard: OK (baseline \(baseline), current \(current))")
    }

    print("qualityguard: OK")
  }

  // MARK: - Help

  private static func printHelp() {
    let help = """
    qualityguard v\(version) - Block test deletions and coverage drops

    USAGE:
      qualityguard [OPTIONS]

    OPTIONS:
      --config <path>   Path to config file (default: .qualityguard.json)
      --range <range>   Git range to diff (default: from config)
      --help, -h        Show this help message
      --version, -v     Show version number

    CONFIGURATION (.qualityguard.json):
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

    SUPPORTED TEST PATTERNS:
      - XCTest:        func testSomething()
      - Swift Testing: @Test func something()
      - Swift Testing: @Test("name") func something()
      - Swift Testing: @Suite struct SomeTests { }

    BYPASS:
      Set the environment variable specified in allowEnvVar to "1":
        ALLOW_TEST_DELETIONS=1 qualityguard

    EXAMPLES:
      # Run with default config
      qualityguard

      # Run with custom config
      qualityguard --config .qualityguard-strict.json

      # Run with custom range
      qualityguard --range "HEAD~5...HEAD"

    EXIT CODES:
      0  All checks passed
      1  Violation detected or error occurred
    """
    print(help)
  }

  // MARK: - Process helpers

  private static func git(_ argv: [String]) throws -> String {
    let (code, stdout, stderr) = try runProc(exe: "/usr/bin/env", args: ["git"] + argv)
    guard code == 0 else { throw QGError.gitFailed(code, stdout + stderr) }
    return stdout
  }

  private static func sh(_ command: String) throws -> String {
    let (code, stdout, stderr) = try runProc(exe: "/bin/bash", args: ["-lc", command])
    guard code == 0 else { throw QGError.violation("FAIL: command failed: \(command)\n\(stdout)\(stderr)") }
    return stdout
  }

  /// Runs an external process with separate stdout/stderr capture.
  ///
  /// - Parameters:
  ///   - exe: Path to executable
  ///   - args: Command line arguments
  ///   - timeout: Maximum execution time in seconds (default: 60)
  /// - Returns: Tuple of (exit code, stdout, stderr)
  private static func runProc(
    exe: String,
    args: [String],
    timeout: TimeInterval = 60.0
  ) throws -> (Int32, String, String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: exe)
    p.arguments = args

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    p.standardOutput = stdoutPipe
    p.standardError = stderrPipe

    try p.run()

    // Timeout handling
    let deadline = Date().addingTimeInterval(timeout)
    while p.isRunning && Date() < deadline {
      Thread.sleep(forTimeInterval: 0.1)
    }

    if p.isRunning {
      p.terminate()
      throw QGError.violation("Process exceeded \(Int(timeout))s timeout")
    }

    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

    let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
    let stderr = String(data: stderrData, encoding: .utf8) ?? ""

    // Forward stderr to parent stderr if non-empty
    if !stderr.isEmpty {
      fputs(stderr, Darwin.stderr)
    }

    return (p.terminationStatus, stdout, stderr)
  }
}
