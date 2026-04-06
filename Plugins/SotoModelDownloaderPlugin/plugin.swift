//===----------------------------------------------------------------------===//
//
// This source file is part of the Soto for AWS open source project
//
// Copyright (c) 2026 the Soto project authors
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

@main
struct SotoModelDownloader: CommandPlugin {
    struct SotoModelDownloaderArguments {
        let outputFolder: String
        let configFile: String

        var arguments: [String] {
            [
                "--config-file", configFile,
                "--output-folder", outputFolder,
            ]
        }
    }

    func performCommand(context: PackagePlugin.PluginContext, arguments: [String]) async throws {
        // Get the path to the SotoModelDownloader executable
        let sotoModelDownloaderTool = try context.tool(named: "SotoModelDownloader")
        let sotoModelDownloaderURL = URL(filePath: sotoModelDownloaderTool.path.string)

        // Find the config file (soto.config.json) in the package targets
        let sourceTargetFiles = context.package.targets.compactMap { $0 as? SourceModuleTarget }
        let filePathArray = sourceTargetFiles.compactMap { target -> (SourceModuleTarget, Path)? in
            target.sourceFiles.first { $0.path.lastComponent.contains("soto.config.json") }.map {
                (target, $0.path)
            }
        }
        // Ensure a target with the config file is found
        guard filePathArray.count > 0 else {
            Diagnostics.error("Cannot find the soto.config.json file in the target")
            return
        }

        for files in filePathArray {
            // Determine the main directory and output folder for the downloaded resources
            let mainDirectory = files.0.directory
            let outputFolderPath = mainDirectory.appending("aws-models").string

            // Prepare arguments for downloading model files
            let downloaderArgs = SotoModelDownloaderArguments(
                outputFolder: outputFolderPath,
                configFile: files.1.string
            )

            // Set up the process to run the SotoModelDownloader
            let process = Process()
            process.executableURL = sotoModelDownloaderURL
            process.arguments = downloaderArgs.arguments

            // Run the process and wait for it to complete
            try process.run()
            process.waitUntilExit()

            // Check the process termination status
            if process.terminationReason == .exit && process.terminationStatus == 0 {
                print("Downloaded resources to: \(outputFolderPath)")
            } else {
                let terminationDescription = "\(process.terminationReason):\(process.terminationStatus)"
                Diagnostics.error("SotoModelDownloader invocation failed: \(terminationDescription)")
            }
        }
    }
}
