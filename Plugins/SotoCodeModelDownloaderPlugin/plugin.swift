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
        
    func performCommand(context: PackagePlugin.PluginContext, arguments: [String]) async throws {
 
        // get config File
        let configfile = context.package.targets.compactMap({ $0 as? SourceModuleTarget })
                                             .compactMap({ $0.sourceFiles
                                                 .first(where: { $0.path.lastComponent
                                                     .contains("soto.config.json") })?.path }).first
        
        guard let configfile else {
            Diagnostics.error("can not find the soto.config.json file in the target")
            return
        }
        
        // extracting services from config
        let services = try getSerivesFrom(path: configfile.string)
        
        let mainDirectory = configfile.removingLastComponent()
        let outputFolder = mainDirectory.appending("aws").string
        
        // Download Model files
        let modelDownloader = GitHubResource(inputFolder: Repo.modelDirectory,
                                          outputFolder: outputFolder + "/models",
                                          expectedServices: services)
        // Download Endpoint File
        let endpointDownloader = GitHubResource(inputFolder: Repo.endpointsDirectory,
                                            outputFolder: outputFolder)
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for resource in [endpointDownloader, modelDownloader] {
                group.addTask {
                    try await resource.download()
                }
            }
            try await group.waitForAll()
        }
        print("Downloaded resources in : \(outputFolder)")
    }
    
    private func getSerivesFrom(path: String) throws -> [String] {
        let data = try Data(contentsOf: URL(filePath: path))
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String : Any] else { return [] }
        if let services = json["services"] as? [String : Any] {
            let servicesName = services.keys.map({ $0 })
            return servicesName
        }
        return []
    }
}
