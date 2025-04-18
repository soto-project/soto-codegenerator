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

import ArgumentParser
import Foundation
import Logging
import SotoCodeGeneratorLib

@main
struct Command: AsyncParsableCommand, SotoCodeGenCommand {
    @Option(name: .long, help: "Folder to output service files to")
    var outputFolder: String

    @Option(name: .long, help: "Folder to find model files")
    var inputFolder: String?

    @Option(name: .shortAndLong, help: "Input model file")
    var inputFile: String?

    @Option(name: [.short, .customLong("config")], help: "Configuration file")
    var configFile: String?

    @Option(name: .shortAndLong, help: "Prefix applied to output swift files")
    var prefix: String?

    @Option(name: .shortAndLong, help: "Endpoint JSON file")
    var endpoints: String?

    @Option(name: .shortAndLong, help: "Only output files for specified module")
    var module: String?

    @Flag(name: .long, inversion: .prefixedNo, help: "Output files")
    var output: Bool = true

    @Flag(name: .long, help: "HTML comments")
    var htmlComments: Bool = false

    @Flag(name: .long, help: "Load smithy")
    var smithy: Bool = false

    @Option(name: .long, help: "Log Level (trace, debug, info, error)")
    var logLevel: String?

    static var rootPath: String {
        #file
            .split(separator: "/", omittingEmptySubsequences: false)
            .dropLast(3)
            .map { String(describing: $0) }
            .joined(separator: "/")
    }

    static var defaultOutputFolder: String { "\(rootPath)/aws/services" }
    static var defaultInputFolder: String { "\(rootPath)/aws/models" }

    func run() async throws {
        try await SotoCodeGen(command: self).generate()
    }
}
