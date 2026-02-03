import PackagePlugin
import Foundation

@main
struct APIGuardPlugin: CommandPlugin {
  func performCommand(context: PluginContext, arguments: [String]) throws {
    let tool = try context.tool(named: "APIGuardCLI")
    let toolURL = URL(fileURLWithPath: tool.url.path)

    // Use current working directory (where swift package was invoked)
    // not context.package.directoryURL (which points to the plugin's package)
    let workingDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let configDefault = workingDir.appendingPathComponent(".apiguard.json").path

    var args = arguments
    if !args.contains("--config") {
      args.append("--config")
      args.append(configDefault)
    }

    let process = Process()
    process.executableURL = toolURL
    process.arguments = args
    process.currentDirectoryURL = workingDir
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
    case .toolFailed(let code):
      return "apiguard failed with exit code \(code)"
    }
  }
}
