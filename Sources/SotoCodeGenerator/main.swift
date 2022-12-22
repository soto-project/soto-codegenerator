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

struct Command: ParsableCommand, SotoCodeGenCommand {
    @Option(name: .long, help: "Folder to output service files to")
    var outputFolder: String

    @Option(name: .long, help: "Folder to find model files")
    var inputFolder: String?

    @Option(name: .shortAndLong, help: "Input model file")
    var inputFile: String?

    @Option(name: .shortAndLong, help: "Prefix applied to output swift files")
    var prefix: String?

    @Option(name: .shortAndLong, help: "Endpoint JSON file")
    var endpoints: String = Self.defaultEndpoints

    @Option(name: .shortAndLong, help: "Only output files for specified module")
    var module: String?

    @Flag(name: .long, inversion: .prefixedNo, help: "Output files")
    var output: Bool = true

    @Flag(name: [.customShort("f"), .customLong("format")], inversion: .prefixedNo, help: "Run swift format on output")
    var swiftFormat: Bool = false

    @Flag(name: .long, help: "HTML comments")
    var htmlComments: Bool = false

    @Flag(name: .long, help: "Load smithy")
    var smithy: Bool = false

    @Option(name: .long, help: "Log Level (trace, debug, info, error)")
    var logLevel: String?

    static var rootPath: String {
        return #file
            .split(separator: "/", omittingEmptySubsequences: false)
            .dropLast(3)
            .map { String(describing: $0) }
            .joined(separator: "/")
    }

    static var defaultOutputFolder: String { return "\(rootPath)/aws/services" }
    static var defaultInputFolder: String { return "\(rootPath)/aws/models" }
    static var defaultEndpoints: String { return "\(rootPath)/aws/endpoints.json" }

    func run() throws {
        try SotoCodeGen(command: self).generate()
    }
}

Command.main()
