//===----------------------------------------------------------------------===//
//
// This source file is part of the Soto for AWS open source project
//
// Copyright (c) 2017-2022 the Soto project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Soto project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import Logging
import Mustache
import SotoSmithy
import SotoSmithyAWS

public protocol SotoCodeGenCommand {
    var inputFile: String? { get }
    var configFile: String? { get }
    var prefix: String? { get }
    var outputFolder: String { get }
    var inputFolder: String? { get }
    var endpoints: String? { get }
    var module: String? { get }
    var output: Bool { get }
    var htmlComments: Bool { get }
    var smithy: Bool { get }
    var logLevel: String? { get }
}

public struct SotoCodeGen {
    struct FileError: Error {
        let filename: String
        let error: Error
    }

    let command: SotoCodeGenCommand
    let library: MustacheLibrary
    let logger: Logging.Logger

    public init(command: SotoCodeGenCommand) throws {
        self.command = command
        self.library = try Templates.createLibrary()
        var logger = Logging.Logger(label: "SotoCodeGenerator")
        logger.logLevel = self.command.logLevel.map { Logging.Logger.Level(rawValue: $0) ?? .info } ?? .info
        self.logger = logger
    }

    public func generate() async throws {
        let startTime = Date()

        // load JSON
        let config = try loadConfigFile()
        let endpoints = try loadEndpointJSON()
        let modelFiles: [String]
        if self.command.smithy {
            modelFiles = self.getSmithyFiles()
        } else {
            modelFiles = self.getModelFiles()
        }

        Smithy.registerShapesAndTraits()
        Smithy.registerAWSTraits()
        Smithy.registerTraitTypes(
            SotoInputShapeTrait.self,
            SotoOutputShapeTrait.self
        )

        try await withThrowingTaskGroup(of: Void.self) { group in
            for file in modelFiles {
                group.addTask {
                    do {
                        let model: SotoSmithy.Model
                        if self.command.smithy {
                            model = try self.loadSmithy(filename: file)
                        } else {
                            model = try self.loadJSONAST(filename: file)
                        }
                        // get service filename without path and extension
                        let filename =
                            file
                            .split(separator: "/", omittingEmptySubsequences: true).last!
                        let filenameWithoutExtension = String(filename[..<(filename.lastIndex(of: ".") ?? filename.endIndex)])
                        let filter = config.services?[filenameWithoutExtension]?.operations
                        let service = try AwsService(
                            model,
                            endpoints: endpoints,
                            filter: filter,
                            outputHTMLComments: self.command.htmlComments,
                            logger: self.logger
                        )

                        if self.command.output {
                            try self.generateFiles(with: service, config: config)
                        }
                    } catch {
                        self.logger.error("\(file): \(error)")
                        exit(1)
                    }
                }
            }
            try await group.waitForAll()
        }

        if modelFiles.count > 1 {
            self.logger.info("Code Generation took \(Int(-startTime.timeIntervalSinceNow)) seconds")
        }
    }

    func getModelFiles() -> [String] {
        if let input = self.command.inputFile {
            return [input]
        } else if let inputFolder = self.command.inputFolder {
            if let module = command.module {
                return Glob.entries(pattern: "\(inputFolder)/\(module)*/service/*/*.json")
                    + Glob.entries(pattern: "\(inputFolder)/\(module)*.json")
            } else {
                return Glob.entries(pattern: "\(inputFolder)/*/service/*/*.json")
                    + Glob.entries(pattern: "\(inputFolder)/*.json")
            }
        } else {
            return []
        }
    }

    func getSmithyFiles() -> [String] {
        if let input = self.command.inputFile {
            return [input]
        } else if let inputFolder = self.command.inputFolder {
            if let module = command.module {
                return Glob.entries(pattern: "\(inputFolder)/\(module)*/service/*/*.smithy")
                    + Glob.entries(pattern: "\(inputFolder)/\(module)*.smithy")
            } else {
                return Glob.entries(pattern: "\(inputFolder)/*/service/*/*.smithy")
                    + Glob.entries(pattern: "\(inputFolder)/*.smithy")
            }
        } else {
            return []
        }
    }

    func loadConfigFile() throws -> ConfigFile {
        if let configFile = self.command.configFile {
            let configData = try Data(contentsOf: URL(fileURLWithPath: configFile))
            let config = try JSONDecoder().decode(ConfigFile.self, from: configData)
            return config
        } else {
            return .init(services: [:], access: .public)
        }
    }

    func loadEndpointJSON() throws -> Endpoints {
        if let endpoints = self.command.endpoints {
            let data = try Data(contentsOf: URL(fileURLWithPath: endpoints))
            return try JSONDecoder().decode(Endpoints.self, from: data)
        } else {
            return .init(partitions: [])
        }
    }

    func loadModelJSON() throws -> [String: SotoSmithy.Model] {
        let modelFiles = self.getModelFiles()

        return try .init(
            modelFiles.map {
                try (key: $0, value: self.loadJSONAST(filename: $0))
            }
        ) { left, _ in left }
    }

    func loadJSONAST(filename: String) throws -> SotoSmithy.Model {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: filename))
            let model = try Smithy().decodeAST(from: data)
            try model.validate()
            return model
        } catch {
            throw FileError(filename: filename, error: error)
        }
    }

    func loadSmithy() throws -> [String: SotoSmithy.Model] {
        let modelFiles = self.getSmithyFiles()

        return try .init(
            modelFiles.map {
                try (key: $0, value: self.loadSmithy(filename: $0))
            }
        ) { left, _ in left }
    }

    func loadSmithy(filename: String) throws -> SotoSmithy.Model {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: filename))
            let string = String(decoding: data, as: Unicode.UTF8.self)
            let model = try Smithy().parse(string)
            try model.validate()
            return model
        } catch {
            throw FileError(filename: filename, error: error)
        }
    }

    /// Generate service files from AWSService
    /// - Parameter codeGenerator: service generated from JSON
    func generateFiles(with service: AwsService, config: ConfigFile) throws {
        let basePath: String
        let prefix: String
        if self.command.inputFile == nil {
            basePath = "\(self.command.outputFolder)/\(service.serviceName)"
            prefix = service.serviceName
            try FileManager.default.createDirectory(atPath: basePath, withIntermediateDirectories: true)
        } else {
            basePath = "\(self.command.outputFolder)"
            prefix = self.command.prefix.map { $0.replacingOccurrences(of: "-", with: "_") } ?? service.serviceName
        }
        let scope = config.access?.rawValue ?? "public"

        var shapesContext = try service.generateShapesContext()
        var apiContext = try service.generateServiceContext()
        shapesContext.scope = scope
        apiContext["scope"] = scope

        let api = self.library.render(apiContext, withTemplate: "api")!
        if try api
            .writeIfChanged(toFile: "\(basePath)/\(prefix)_api.swift")
        {
            self.logger.info("Wrote \(prefix)_api.swift")
        }

        let shapes = self.library.render(shapesContext, withTemplate: "shapes")!
        if self.command.output,
            try shapes.writeIfChanged(
                toFile: "\(basePath)/\(prefix)_shapes.swift"
            )
        {
            self.logger.info("Wrote \(prefix)_shapes.swift")
        }
        self.logger.debug("Succesfully Generated \(service.serviceName)")
    }
}

extension String {
    /// Only writes to file if the string contents are different to the file contents. This is used to stop XCode rebuilding and reindexing files unnecessarily.
    /// If the file is written to XCode assumes it has changed even when it hasn't
    /// - Parameters:
    ///   - toFile: Filename
    ///   - atomically: make file write atomic
    ///   - encoding: string encoding
    func writeIfChanged(toFile: String) throws -> Bool {
        do {
            let original = try String(contentsOfFile: toFile)
            guard original != self else { return false }
        } catch {
            // print(error)
        }
        try write(toFile: toFile, atomically: true, encoding: .utf8)
        return true
    }
}
