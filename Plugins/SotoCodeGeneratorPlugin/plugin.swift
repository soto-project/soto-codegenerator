//===----------------------------------------------------------------------===//
//
// This source file is part of the Soto for AWS open source project
//
// Copyright (c) 2017-2020 the Soto project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Soto project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

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

        // get config file
        let configFile = target.sourceFiles.first { $0.path.lastComponent == "soto.config.json" }?.path

        // get list of AWS Smithy model files (ignore endpoints and config)
        let inputFiles: [FileList.Element] = target.sourceFiles.filter {
            $0.path.extension == "json" && $0.path.stem != "endpoints" && $0.path.stem != "soto.config"
        }

        // return build command for each model file
        return inputFiles.map { file in
            let prefix = file.path.stem.replacingOccurrences(of: "-", with: "_")
            var inputFiles = [file.path]
            if let endpointInTarget = endpointInTarget {
                inputFiles.append(endpointInTarget)
            }
            let configArgs: [String]
            if let configFile = configFile {
                configArgs = ["--config", "\(configFile)"]
                inputFiles.append(configFile)
            } else {
                configArgs = []
            }
            let outputFiles: [Path] = [
                genSourcesDir.appending("\(prefix)_api.swift"),
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
                    "\(endpoints)",
                ] + configArgs,
                inputFiles: inputFiles,
                outputFiles: outputFiles
            )
        }
    }
}
