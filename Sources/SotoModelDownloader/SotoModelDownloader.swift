//===----------------------------------------------------------------------===//
//
// This source file is part of the Soto for AWS open source project
//
// Copyright (c) 2017-2023 the Soto project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Soto project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
import Foundation
import ArgumentParser

@main
struct SotoModelDownloader: AsyncParsableCommand {
    
        /// The folder where the service files will be output.
       @Option(name: .long, help: "Folder to output service files to")
       var outputFolder: String

       /// The folder where the model files are located.
       @Option(name: .long, help: "Folder to find model files")
       var inputFolder: String
       
       /// The configuration file, if provided.
       @Option(name: [.short, .customLong("config")], help: "Configuration file")
       var configFile: String?
       
       /// The main entry point of the command.
       func run() async throws {
           let resource: GitHubResource
           
           if let configFile = configFile {
               // Decode the configuration file to get the list of services
               let sotoConfig = try ConfigFile.decodeFrom(file: configFile)
               let services = sotoConfig.services?.compactMap { $0.key } ?? []
               
               // Initialize the GitHubResource with a model filter
               resource = GitHubResource(inputFolder: inputFolder,
                                         outputFolder: outputFolder,
                                         modelFilter: services)
           } else {
               // Initialize the GitHubResource without a model filter
               resource = GitHubResource(inputFolder: inputFolder,
                                         outputFolder: outputFolder)
           }

           // Start the download process
           try await resource.download()
       }
}
