import PackagePlugin
import Foundation

@main
struct ChangeGuardPlugin: CommandPlugin {
  func performCommand(context: PluginContext, arguments: [String]) throws {
    let tool = try context.tool(named: "changeguard")
    let toolURL = URL(fileURLWithPath: tool.url.path)

    let configDefault = context.package.directoryURL.appendingPathComponent(".changeguard.json").path
    var args = arguments
    if !args.contains("--config") {
      args.append("--config")
      args.append(configDefault)
    }

    let process = Process()
    process.executableURL = toolURL
    process.arguments = args
    process.currentDirectoryURL = context.package.directoryURL
    try process.run()
    process.waitUntilExit()

    if process.terminationStatus != 0 {
      throw CommandError.toolFailed(process.terminationStatus)
    }
  }
}

enum CommandError: Error, CustomStringConvertible {
  case toolFailed(Int32)
  var description: String {
    switch self {
    case .toolFailed(let code): return "changeguard failed with exit code \(code)"
    }
  }
}
