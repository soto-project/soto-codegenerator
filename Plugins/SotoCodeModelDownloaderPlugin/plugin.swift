//===----------------------------------------------------------------------===//
//
// This source file is part of the Soto for AWS open source project
//
// Copyright (c) 2017-2024 the Soto project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Soto project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
import PackagePlugin
import Foundation

@main
struct SotoCodeModelDownloader: CommandPlugin {
        
    struct ModelDownloaderArguments {
        let inputFolder: String
        let outputFolder: String
        let configFile: String?
        
        func getArguments() -> [String] {
            // Construct the command line arguments for the model downloader
            var arguments = ["--input-folder", inputFolder,
                             "--output-folder", outputFolder]
            if let configFilePath = configFile {
                arguments.append(contentsOf: ["--config", configFilePath])
            }
            return arguments
        }
    }

    func performCommand(context: PackagePlugin.PluginContext, arguments: [String]) async throws {
        // Get the path to the SotoModelDownloader executable
        let sotoModelDownloaderTool = try context.tool(named: "SotoModelDownloader")
        let sotoModelDownloaderURL = URL(filePath: sotoModelDownloaderTool.path.string)
        
        // Find the config file (soto.config.json) in the package targets
        let configFile = context.package.targets
            .compactMap({ $0 as? SourceModuleTarget })
            .compactMap({ $0.sourceFiles.first(where: { $0.path.lastComponent.contains("soto.config.json") })?.path })
            .first
        
        // Ensure the config file is found
        guard let configFile else {
            Diagnostics.error("Cannot find the soto.config.json file in the target")
            return
        }
        
        // Determine the main directory and output folder for the downloaded resources
        let mainDirectory = configFile.removingLastComponent()
        let outputFolderPath = mainDirectory.appending("aws").string

        // Prepare arguments for downloading model files
        let modelDownloaderArgs = ModelDownloaderArguments(
            inputFolder: Repo.modelDirectory,
            outputFolder: outputFolderPath + "/models",
            configFile: configFile.string
        )
        
        // Prepare arguments for downloading endpoint files
        let endpointDownloaderArgs = ModelDownloaderArguments(
            inputFolder: Repo.endpointsDirectory,
            outputFolder: outputFolderPath,
            configFile: nil
        )

        // Iterate over the download tasks (models and endpoints)
        for resourceArgs in [endpointDownloaderArgs, modelDownloaderArgs] {
            // Set up the process to run the SotoModelDownloader
            let process = Process()
            process.executableURL = sotoModelDownloaderURL
            process.arguments = resourceArgs.getArguments()
            
            // Run the process and wait for it to complete
            try process.run()
            process.waitUntilExit()
            
            // Check the process termination status
            if process.terminationReason == .exit && process.terminationStatus == 0 {
                print("Downloaded resources to: \(outputFolderPath)")
            } else {
                let terminationDescription = "\(process.terminationReason):\(process.terminationStatus)"
                throw "get-soto-models invocation failed: \(terminationDescription)"
            }
        }
    }
}

extension String: Error {}

// MARK: - Model and Endpoint URLs -

enum Repo {
    /// Model files github directory.
    static let modelDirectory = "https://github.com/soto-project/soto/tree/main/models"
    
    /// Endpoints github directory.
    static let endpointsDirectory = "https://github.com/soto-project/soto/tree/main/models/endpoints"
}
