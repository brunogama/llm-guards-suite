import Foundation

struct ChangeGuardConfig: Decodable {
  let range: String
  let pathspecs: [String]
  let maxFilesChanged: Int
  let maxTotalChangedLines: Int
  let maxWhitespaceRatio: Double
  let allowEnvVar: String
}

enum CGError: Error, CustomStringConvertible {
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

@main
enum ChangeGuard {
  static let version = "1.1.0"

  static func main() {
    do {
      try run()
    } catch let e as CGError {
      fputs(e.description + "\n", stderr)
      exit(1)
    } catch {
      fputs("changeguard error: \(error)\n", stderr)
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
        print("changeguard \(version)")
        return
      case "--config":
        i += 1
        guard i < args.count else { throw CGError.invalidArguments("Missing value for --config") }
        configPath = args[i]
      case "--range":
        i += 1
        guard i < args.count else { throw CGError.invalidArguments("Missing value for --range") }
        rangeOverride = args[i]
      default:
        break
      }
      i += 1
    }

    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let resolvedConfig = configPath ?? ".changeguard.json"
    // Handle both absolute and relative paths
    let cfgURL: URL
    if resolvedConfig.hasPrefix("/") {
      cfgURL = URL(fileURLWithPath: resolvedConfig)
    } else {
      cfgURL = cwd.appendingPathComponent(resolvedConfig)
    }

    guard FileManager.default.fileExists(atPath: cfgURL.path) else {
      throw CGError.configNotFound(cfgURL.path)
    }

    let cfgData = try Data(contentsOf: cfgURL)
    let cfg: ChangeGuardConfig
    do {
      cfg = try JSONDecoder().decode(ChangeGuardConfig.self, from: cfgData)
    } catch {
      throw CGError.configDecodeFailed(error.localizedDescription)
    }

    if let allow = ProcessInfo.processInfo.environment[cfg.allowEnvVar], allow == "1" {
      print("changeguard: bypassed via \(cfg.allowEnvVar)=1")
      return
    }

    let range = rangeOverride ?? cfg.range
    let pathspecs = cfg.pathspecs

    // 1) Files changed count
    let nameOnly = try git(["diff", "--name-only", range, "--"] + pathspecs)
    let files = nameOnly
      .split(separator: "\n")
      .map(String.init)
      .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    if files.count > cfg.maxFilesChanged {
      var msg = "FAIL: Files changed: \(files.count) (max \(cfg.maxFilesChanged))\n"
      for f in files.prefix(50) { msg += "  \(f)\n" }
      throw CGError.violation(msg)
    }

    // 2) Total changed lines (added+deleted)
    let totalNumstat = try git(["diff", "--numstat", range, "--"] + pathspecs)
    let totalChanged = sumChangedLines(fromNumstat: totalNumstat)

    if totalChanged > cfg.maxTotalChangedLines {
      throw CGError.violation("FAIL: Total changed lines: \(totalChanged) (max \(cfg.maxTotalChangedLines))")
    }

    // 3) Whitespace churn ratio
    // semanticChanged is diff with -w (ignore whitespace changes)
    let semanticNumstat = try git(["diff", "-w", "--numstat", range, "--"] + pathspecs)
    let semanticChanged = sumChangedLines(fromNumstat: semanticNumstat)

    let whitespaceOnly = max(0, totalChanged - semanticChanged)
    let ratio = totalChanged == 0 ? 0.0 : Double(whitespaceOnly) / Double(totalChanged)

    if ratio > cfg.maxWhitespaceRatio {
      let msg = String(
        format: "FAIL: Whitespace churn ratio %.2f (max %.2f). total=%d semantic=%d whitespaceOnly=%d",
        ratio, cfg.maxWhitespaceRatio, totalChanged, semanticChanged, whitespaceOnly
      )
      throw CGError.violation(msg)
    }

    print("changeguard: OK (files=\(files.count), totalChanged=\(totalChanged), whitespaceRatio=\(String(format: "%.2f", ratio)))")
  }

  private static func sumChangedLines(fromNumstat text: String) -> Int {
    var total = 0
    for line in text.split(separator: "\n") {
      let parts = line.split(separator: "\t")
      if parts.count >= 2 {
        // '-' can appear for binary files; treat as 0
        let add = Int(parts[0]) ?? 0
        let del = Int(parts[1]) ?? 0
        total += add + del
      }
    }
    return total
  }

  // MARK: - Help

  private static func printHelp() {
    let help = """
    changeguard v\(version) - Enforce minimal diffs

    USAGE:
      changeguard [OPTIONS]

    OPTIONS:
      --config <path>   Path to config file (default: .changeguard.json)
      --range <range>   Git range to diff (default: from config)
      --help, -h        Show this help message
      --version, -v     Show version number

    CONFIGURATION (.changeguard.json):
      {
        "range": "origin/main...HEAD",
        "pathspecs": ["Sources/**", "Tests/**", "Package.swift"],
        "maxFilesChanged": 10,
        "maxTotalChangedLines": 400,
        "maxWhitespaceRatio": 0.3,
        "allowEnvVar": "ALLOW_LARGE_DIFF"
      }

    CHECKS:
      1. File count: Number of files changed
      2. Line count: Total added + deleted lines
      3. Whitespace ratio: (total - semantic) / total
         Detects formatter storms

    BYPASS:
      Set the environment variable specified in allowEnvVar to "1":
        ALLOW_LARGE_DIFF=1 changeguard

    EXAMPLES:
      # Run with default config
      changeguard

      # Run with custom config
      changeguard --config .changeguard-strict.json

      # Run with custom range
      changeguard --range "HEAD~5...HEAD"

    EXIT CODES:
      0  All checks passed
      1  Violation detected or error occurred
    """
    print(help)
  }

  // MARK: - Process helpers

  private static func git(_ argv: [String]) throws -> String {
    let (code, stdout, stderr) = try runProc(exe: "/usr/bin/env", args: ["git"] + argv)
    guard code == 0 else { throw CGError.gitFailed(code, stdout + stderr) }
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
      throw CGError.violation("Process exceeded \(Int(timeout))s timeout")
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
