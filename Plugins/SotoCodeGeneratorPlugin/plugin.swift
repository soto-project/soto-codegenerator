import Foundation
import PackagePlugin

@main struct SwiftCodeGeneratorPlugin: BuildToolPlugin {
    func createBuildCommands(
        context: PluginContext,
        target: Target
    ) throws -> [Command] {
        // This example configures the commands to write to a "GeneratedSources"
        // directory.
        let genSourcesDir = context.pluginWorkDirectory.appending("GeneratedSources")

        // We only generate commands for source targets.
        guard let target = target as? SourceModuleTarget else { return [] }

        // SotoCodeGenerator executable path
        let sotoCodeGenerator = try context.tool(named: "SotoCodeGenerator").path

        let path: Path = target.directory
        let baseDirectory = path.removingLastComponent().removingLastComponent()
        let endpoints = baseDirectory.appending("Models", "endpoints.json")

        let inputFiles: [FileList.Element] = target.sourceFiles.filter { $0.path.extension == "json" }

        let commands: [Command] = inputFiles.map { file in
            let prefix = file.path.stem.replacingOccurrences(of: "-", with: "_")
            let outputFiles: [Path] = [
                genSourcesDir.appending("\(prefix)_api.swift"),
                genSourcesDir.appending("\(prefix)_api+async.swift"),
                genSourcesDir.appending("\(prefix)_shapes.swift"),
            ]
            return .buildCommand(
                displayName: "Running SotoCodeGenerator",
                executable: sotoCodeGenerator,
                arguments: [
                    "--input-file",
                    file.path,
                    "--prefix",
                    prefix,
                    "--output-folder",
                    genSourcesDir,
                    "--endpoints",
                    "\(endpoints)"
                ],
                inputFiles: [file.path],
                outputFiles: outputFiles
            )
        }
        return commands
    }
}
