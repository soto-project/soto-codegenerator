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

struct SotoCodeGenCommand: ParsableCommand {
    @Option(name: .shortAndLong, help: "Folder to output service files to")
    var outputFolder: String = Self.defaultOutputFolder

    @Option(name: .shortAndLong, help: "Folder to find json model files")
    var inputFolder: String = Self.defaultInputFolder

    @Option(name: .shortAndLong, help: "Endpoint JSON file")
    var endpoints: String = Self.defaultEndpoints

    @Option(name: .shortAndLong, help: "Only output files for specified module")
    var module: String?

    @Flag(name: .long, inversion: .prefixedNo, help: "Output files")
    var output: Bool = true

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

SotoCodeGenCommand.main()
