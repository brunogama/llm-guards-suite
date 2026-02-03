import Foundation

struct APIGuardConfig: Decodable {
  enum Mode: String, Decodable { case semver, strict }

  let targets: [String]
  let mode: Mode
  let baselineDir: String
  let outputDir: String
  let failOnAdditions: Bool
}

struct APISnapshot: Codable {
  let target: String
  let createdAt: String
  let symbols: [String: String] // preciseID -> declaration
}

enum APIGuardError: Error, CustomStringConvertible {
  case invalidArguments(String)
  case configNotFound(String)
  case configDecodeFailed(String)
  case swiftToolFailed(Int32, String)
  case baselineMissing(String)
  case breakingChanges(String)
  case strictChanges(String)

  var description: String {
    switch self {
    case .invalidArguments(let s): return s
    case .configNotFound(let p): return "Config not found: \(p)"
    case .configDecodeFailed(let s): return "Config decode failed: \(s)"
    case .swiftToolFailed(let code, let out): return "swift tool failed (\(code))\n\(out)"
    case .baselineMissing(let t): return "API baseline missing for target: \(t)"
    case .breakingChanges(let s): return s
    case .strictChanges(let s): return s
    }
  }
}

struct SymbolGraph: Decodable {
  struct Symbol: Decodable {
    struct Identifier: Decodable { let precise: String }
    struct Name: Decodable { let title: String }
    struct Kind: Decodable { let identifier: String; let displayName: String? }
    struct DeclarationFragment: Decodable {
      let kind: String
      let spelling: String
    }

    let identifier: Identifier
    let names: Name
    let kind: Kind
    let accessLevel: String?
    let declarationFragments: [DeclarationFragment]?
  }

  let symbols: [Symbol]
}

enum SnapshotBuilder {
  static func build(target: String, symbolGraphURL: URL) throws -> APISnapshot {
    let data = try Data(contentsOf: symbolGraphURL)
    let graph = try JSONDecoder().decode(SymbolGraph.self, from: data)

    var map: [String: String] = [:]
    map.reserveCapacity(graph.symbols.count)

    for s in graph.symbols {
      // Symbol graphs include many non-public symbols; keep only public/open.
      // accessLevel may be missing for some symbols; treat missing as non-public.
      guard let level = s.accessLevel, (level == "public" || level == "open") else { continue }

      let decl = normalizeDeclaration(s)
      map[s.identifier.precise] = decl
    }

    return APISnapshot(
      target: target,
      createdAt: ISO8601DateFormatter().string(from: Date()),
      symbols: map
    )
  }

  private static func normalizeDeclaration(_ s: SymbolGraph.Symbol) -> String {
    if let frags = s.declarationFragments, !frags.isEmpty {
      // Join spellings; strip repeated whitespace for stability
      let joined = frags.map { $0.spelling }.joined()
      return joined.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    // Fallback: kind + title (less precise but stable)
    let kind = s.kind.identifier
    let title = s.names.title
    return "\(kind) \(title)"
  }
}

enum SwiftPM {
  static func dumpSymbolGraph(target: String, outputDir: URL) throws -> URL {
    try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

    // Swift 6.0 swift package dump-symbol-graph doesn't support --target or --output-dir
    // It outputs to .build/symbol-graphs/ by default
    // Use longer timeout (600s) for large projects
    let (status, stdout, stderr) = try run([
      "swift", "package", "dump-symbol-graph"
    ], timeout: 600.0)

    guard status == 0 else { throw APIGuardError.swiftToolFailed(status, stdout + stderr) }

    // Symbol graphs are output to .build/symbol-graphs/ with names like:
    // TargetName.symbols.json or TargetName@swift-x.x-platform.symbols.json
    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let symbolGraphsDir = cwd.appendingPathComponent(".build/symbol-graphs")

    guard FileManager.default.fileExists(atPath: symbolGraphsDir.path) else {
      throw APIGuardError.swiftToolFailed(status, "Symbol graphs directory not found at .build/symbol-graphs/")
    }

    let files = try FileManager.default.contentsOfDirectory(at: symbolGraphsDir, includingPropertiesForKeys: [.contentModificationDateKey])
      .filter { url in
        let name = url.lastPathComponent
        // Match TargetName.symbols.json or TargetName@swift-x.x-platform.symbols.json
        return name.hasSuffix(".symbols.json") && (name.hasPrefix("\(target).") || name.hasPrefix("\(target)@"))
      }

    guard let newest = files.sorted(by: { (a, b) in
      let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
      let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
      return da < db
    }).last else {
      throw APIGuardError.swiftToolFailed(status, "No .symbols.json produced for target \(target)")
    }

    // Copy the symbol graph to our output directory for consistency
    let destURL = outputDir.appendingPathComponent("\(target).symbols.json")
    try? FileManager.default.removeItem(at: destURL)
    try FileManager.default.copyItem(at: newest, to: destURL)

    return destURL
  }

  /// Runs an external process with separate stdout/stderr capture.
  ///
  /// - Parameters:
  ///   - argv: Command and arguments
  ///   - timeout: Maximum execution time in seconds (default: 120 for builds)
  /// - Returns: Tuple of (exit code, stdout, stderr)
  private static func run(_ argv: [String], timeout: TimeInterval = 120.0) throws -> (Int32, String, String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    p.arguments = argv

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
      throw APIGuardError.swiftToolFailed(-1, "Process exceeded \(Int(timeout))s timeout")
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

enum BaselineStore {
  static func load(baselineDir: URL, target: String) throws -> APISnapshot {
    let url = baselineDir.appendingPathComponent("\(target).json")
    guard FileManager.default.fileExists(atPath: url.path) else {
      throw APIGuardError.baselineMissing(target)
    }
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(APISnapshot.self, from: data)
  }

  static func save(snapshot: APISnapshot, baselineDir: URL) throws {
    try FileManager.default.createDirectory(at: baselineDir, withIntermediateDirectories: true)
    let url = baselineDir.appendingPathComponent("\(snapshot.target).json")

    // Write canonical JSON (sorted keys) for stable diffs
    let any: Any = [
      "target": snapshot.target,
      "createdAt": snapshot.createdAt,
      "symbols": snapshot.symbols
    ]
    let data = try CanonicalJSON.encode(any)
    try data.write(to: url, options: [.atomic])
  }
}

struct APIDiff {
  let added: [String]
  let removed: [String]
  let changed: [String]

  static func between(old: APISnapshot, new: APISnapshot) -> APIDiff {
    let oldKeys = Set(old.symbols.keys)
    let newKeys = Set(new.symbols.keys)

    let added = Array(newKeys.subtracting(oldKeys)).sorted()
    let removed = Array(oldKeys.subtracting(newKeys)).sorted()

    var changed: [String] = []
    changed.reserveCapacity(min(old.symbols.count, new.symbols.count))
    for id in oldKeys.intersection(newKeys) {
      if old.symbols[id] != new.symbols[id] {
        changed.append(id)
      }
    }
    changed.sort()
    return APIDiff(added: added, removed: removed, changed: changed)
  }
}

// MARK: - Main Entry Point

@main
enum APIGuard {
  static let version = "1.1.0"

  static func main() {
    do {
      try run()
    } catch let e as APIGuardError {
      fputs(e.description + "\n", stderr)
      Foundation.exit(1)
    } catch {
      fputs("apiguard error: \(error)\n", stderr)
      Foundation.exit(1)
    }
  }

  private static func printHelp() {
    let help = """
    apiguard v\(version) - Block breaking API changes

    USAGE:
      apiguard [OPTIONS]

    OPTIONS:
      --config <path>   Path to config file (default: .apiguard.json)
      --update          Update baseline snapshots with current API
      --help, -h        Show this help message
      --version, -v     Show version number

    CONFIGURATION (.apiguard.json):
      {
        "targets": ["YourPublicTarget"],
        "mode": "semver",
        "baselineDir": "api-baseline",
        "outputDir": ".build/apiguard",
        "failOnAdditions": false
      }

    MODES:
      - semver:  Fail only on breaking changes (removals, signature changes)
      - strict:  Fail on any API change (additions, removals, changes)

    WORKFLOW:
      1. First run: apiguard --update  (creates baseline)
      2. CI runs:   apiguard           (compares against baseline)
      3. On API change: apiguard --update && commit

    EXAMPLES:
      # Check API against baseline
      apiguard

      # Update baseline after intentional API change
      apiguard --update

      # Use custom config
      apiguard --config .apiguard-strict.json

    EXIT CODES:
      0  No breaking changes (or baseline updated)
      1  Breaking changes detected or error occurred
    """
    print(help)
  }

  private static func run() throws {
    var configPath: String?
    var update = false

    var i = 1
    while i < CommandLine.arguments.count {
      let arg = CommandLine.arguments[i]
      switch arg {
      case "--help", "-h":
        printHelp()
        return
      case "--version", "-v":
        print("apiguard \(version)")
        return
      case "--config":
        i += 1
        guard i < CommandLine.arguments.count else {
          throw APIGuardError.invalidArguments("Missing value for --config")
        }
        configPath = CommandLine.arguments[i]
      case "--update":
        update = true
      default:
        break
      }
      i += 1
    }

    let resolvedConfig = configPath ?? ".apiguard.json"
    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    // Handle both absolute and relative paths
    let cfgURL: URL
    if resolvedConfig.hasPrefix("/") {
      cfgURL = URL(fileURLWithPath: resolvedConfig)
    } else {
      cfgURL = cwd.appendingPathComponent(resolvedConfig)
    }

    guard FileManager.default.fileExists(atPath: cfgURL.path) else {
      throw APIGuardError.configNotFound(cfgURL.path)
    }

    let cfgData = try Data(contentsOf: cfgURL)
    let cfg: APIGuardConfig
    do {
      cfg = try JSONDecoder().decode(APIGuardConfig.self, from: cfgData)
    } catch {
      throw APIGuardError.configDecodeFailed(error.localizedDescription)
    }

    let baselineDir = cwd.appendingPathComponent(cfg.baselineDir)
    let outDir = cwd.appendingPathComponent(cfg.outputDir)

    var hadBreaking = false
    var report = ""

    for target in cfg.targets {
      let perTargetOut = outDir.appendingPathComponent(target)
      try? FileManager.default.removeItem(at: perTargetOut)
      try FileManager.default.createDirectory(at: perTargetOut, withIntermediateDirectories: true)

      let symbolGraphURL = try SwiftPM.dumpSymbolGraph(target: target, outputDir: perTargetOut)
      let current = try SnapshotBuilder.build(target: target, symbolGraphURL: symbolGraphURL)

      if update {
        try BaselineStore.save(snapshot: current, baselineDir: baselineDir)
        report += "Updated baseline: \(target)\n"
        continue
      }

      let old = try BaselineStore.load(baselineDir: baselineDir, target: target)
      let diff = APIDiff.between(old: old, new: current)

      let hasAny = !diff.added.isEmpty || !diff.removed.isEmpty || !diff.changed.isEmpty
      let hasBreaking = !diff.removed.isEmpty || !diff.changed.isEmpty
      let hasAdditive = !diff.added.isEmpty

      if hasAny {
        report += "Target: \(target)\n"
        if !diff.removed.isEmpty { report += "  BREAKING removed: \(diff.removed.count)\n" }
        if !diff.changed.isEmpty { report += "  BREAKING changed: \(diff.changed.count)\n" }
        if !diff.added.isEmpty { report += "  Added: \(diff.added.count)\n" }
      }

      switch cfg.mode {
      case .strict:
        if hasAny {
          hadBreaking = true
          report += "  Result: FAIL (strict mode: any API change is disallowed)\n"
        } else {
          report += "  Result: OK\n"
        }

      case .semver:
        if hasBreaking || (cfg.failOnAdditions && hasAdditive) {
          hadBreaking = true
          report += "  Result: FAIL (semver mode: breaking API change)\n"
        } else {
          report += "  Result: OK\n"
        }
      }
    }

    if update {
      print(report.isEmpty ? "APIGuard: baseline updated." : report)
      return
    }

    if hadBreaking {
      throw APIGuardError.breakingChanges(report.isEmpty ? "APIGuard: breaking API change detected." : report)
    }

    print(report.isEmpty ? "APIGuard: OK (no API changes)" : report + "APIGuard: OK\n")
  }
}
