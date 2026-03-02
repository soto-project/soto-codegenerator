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

import ArgumentParser
import Foundation

#if os(Linux)
import FoundationNetworking
#endif

@main
struct App: AsyncParsableCommand {

    /// The folder where the service files will be output.
    @Option(name: .long, help: "Folder to output service files to")
    var outputFolder: String

    /// The configuration file, if provided.
    @Option(name: .long, help: "Code generator configuration file")
    var configFile: String

    /// GitHub access token.
    @Option(name: [.short, .customLong("--gh-token")], help: "GitHub access token")
    var ghToken: String?

    /// The main entry point of the command.
    func run() async throws {
        guard #available(macOS 13, *) else {
            fatalError("SotoModelDownloader requires macOS 13 or later")
        }

        let downloader = try await Downloader.setup(ghToken: ghToken)
        let config = try await downloader.loadConfig(path: self.configFile)
        for service in config.services.keys {
            try await downloader.writeServiceFile(service, to: outputFolder)
        }
        try await downloader.writeEndpoints(to: outputFolder)
    }
}
