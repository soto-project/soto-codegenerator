import Foundation
import PackagePlugin

/// Generate Swift Service files from AWS Smithy models
@main struct SwiftCodeGeneratorPlugin: BuildToolPlugin {
    func createBuildCommands(
        context: PluginContext,
        target: Target
    ) throws -> [Command] {
        // Configure the commands to write to a "GeneratedSources" directory.
        let genSourcesDir = context.pluginWorkDirectory.appending("GeneratedSources")

        // We only generate commands for source targets.
        guard let target = target as? SourceModuleTarget else { return [] }

        // SotoCodeGenerator executable path
        let sotoCodeGenerator = try context.tool(named: "SotoCodeGenerator").path

        // get endpoint file
        let endpointInTarget = target.sourceFiles.first { $0.path.lastComponent == "endpoints.json" }?.path
        let endpoints = endpointInTarget ?? context.package.directory.appending("endpoints.json")

        // get list of AWS Smithy model files
        let inputFiles: [FileList.Element] = target.sourceFiles.filter { $0.path.extension == "json" && $0.path.stem != "endpoints" }

        // return build command for each model file
        return inputFiles.map { file in
            let prefix = file.path.stem.replacingOccurrences(of: "-", with: "_")
            let outputFiles: [Path] = [
                genSourcesDir.appending("\(prefix)_api.swift"),
                genSourcesDir.appending("\(prefix)_api+async.swift"),
                genSourcesDir.appending("\(prefix)_shapes.swift"),
            ]
            return .buildCommand(
                displayName: "Generating code for \(file.path.lastComponent)",
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
    }
}
