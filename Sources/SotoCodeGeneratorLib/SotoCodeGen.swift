//===----------------------------------------------------------------------===//
//
// This source file is part of the Soto for AWS open source project
//
// Copyright (c) 2017-2021 the Soto project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Soto project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import HummingbirdMustache
import Logging
import SotoSmithy
import SotoSmithyAWS
import SwiftFormat

public protocol SotoCodeGenCommand {
    var inputFile: String? { get }
    var prefix: String? { get }
    var outputFolder: String { get }
    var inputFolder: String? { get }
    var endpoints: String { get }
    var module: String? { get }
    var output: Bool { get }
    var swiftFormat: Bool { get }
    var htmlComments: Bool { get }
    var smithy: Bool { get }
    var logLevel: String? { get }
}

public struct SotoCodeGen {
    struct FileError: Error {
        let filename: String
        let error: Error
    }

    enum SwiftFormatConfig {
        static let disabledRules = FormatRules.disabledByDefault + ["redundantReturn", "redundantBackticks", "trailingCommas", "extensionAccessControl"]
        static let ruleNames = Set(FormatRules.byName.keys).subtracting(disabledRules)
        static let rules: [FormatRule] = ruleNames.map { FormatRules.byName[$0]! }
        static let formatOptions = FormatOptions(
            ifdefIndent: .noIndent,
            wrapArguments: .beforeFirst,
            wrapParameters: .beforeFirst,
            wrapCollections: .beforeFirst,
            hoistPatternLet: false,
            stripUnusedArguments: .unnamedOnly,
            explicitSelf: .insert,
            noSpaceOperators: ["...", "..<"]
        )
    }

    let command: SotoCodeGenCommand
    let library: HBMustacheLibrary
    let logger: Logging.Logger

    public init(command: SotoCodeGenCommand) throws {
        self.command = command
        self.library = try Templates.createLibrary()
        var logger = Logging.Logger(label: "SotoCodeGenerator")
        logger.logLevel = self.command.logLevel.map { Logging.Logger.Level(rawValue: $0) ?? .info } ?? .info
        self.logger = logger
        Smithy.registerAWSTraits()
        Smithy.registerTraitTypes(
            SotoInputShapeTrait.self,
            SotoOutputShapeTrait.self
        )
    }

    public func generate() throws {
        let startTime = Date()

        // load JSON
        let endpoints = try loadEndpointJSON()
        let models: [String: SotoSmithy.Model]
        if self.command.smithy {
            models = try self.loadSmithy()
        } else {
            models = try self.loadModelJSON()
        }
        let group = DispatchGroup()

        models.forEach { model in
            group.enter()

            DispatchQueue.global().async {
                defer { group.leave() }
                do {
                    let service = try AwsService(
                        model.value,
                        endpoints: endpoints,
                        outputHTMLComments: command.htmlComments,
                        logger: self.logger
                    )
                    if self.command.output {
                        try self.generateFiles(with: service)
                    }
                } catch {
                    self.logger.error("\(model.key): \(error)")
                    exit(1)
                }
            }
        }

        group.wait()

        self.logger.info("Code Generation took \(Int(-startTime.timeIntervalSinceNow)) seconds")
        self.logger.info("Done.")
    }

    func getModelFiles() -> [String] {
        if let input = self.command.inputFile {
            return [input]
        } else if let inputFolder = self.command.inputFolder {
            if let module = command.module {
                return Glob.entries(pattern: "\(inputFolder)/\(module)*.json")
            }
            return Glob.entries(pattern: "\(inputFolder)/*.json")
        } else {
            return []
        }
    }

    func getSmithyFiles() -> [String] {
        if let input = self.command.inputFile {
            return [input]
        } else if let inputFolder = self.command.inputFolder {
            if let module = command.module {
                return Glob.entries(pattern: "\(inputFolder)/\(module)*.smithy")
            }
            return Glob.entries(pattern: "\(inputFolder)/*.smithy")
        } else {
            return []
        }
    }

    func loadEndpointJSON() throws -> Endpoints {
        let data = try Data(contentsOf: URL(fileURLWithPath: self.command.endpoints))
        return try JSONDecoder().decode(Endpoints.self, from: data)
    }

    func loadModelJSON() throws -> [String: SotoSmithy.Model] {
        let modelFiles = self.getModelFiles()

        return try .init(modelFiles.map {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: $0))
                let model = try Smithy().decodeAST(from: data)
                try model.validate()
                return (key: $0, value: model)
            } catch {
                throw FileError(filename: $0, error: error)
            }
        }) { left, _ in left }
    }

    func loadSmithy() throws -> [String: SotoSmithy.Model] {
        let modelFiles = self.getSmithyFiles()

        return try .init(modelFiles.map {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: $0))
                let string = String(decoding: data, as: Unicode.UTF8.self)
                let model = try Smithy().parse(string)
                try model.validate()
                return (key: $0, value: model)
            } catch {
                throw FileError(filename: $0, error: error)
            }
        }) { left, _ in left }
    }

    /// Run swift format on String
    func format(_ string: String) throws -> String {
        if self.command.swiftFormat {
            return try SwiftFormat.format(string, rules: Self.SwiftFormatConfig.rules, options: Self.SwiftFormatConfig.formatOptions)
        } else {
            return string
        }
    }

    /// Generate service files from AWSService
    /// - Parameter codeGenerator: service generated from JSON
    func generateFiles(with service: AwsService) throws {
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

        var apiContext = try service.generateServiceContext()
        let paginators = try service.generatePaginatorContext()
        let waiters = try service.generateWaiterContexts()
        if paginators["paginators"] != nil {
            apiContext["paginators"] = paginators
        }
        if waiters["waiters"] != nil {
            apiContext["waiters"] = waiters
        }

        let api = self.library.render(apiContext, withTemplate: "api")!
        if try self.format(api)
            .writeIfChanged(toFile: "\(basePath)/\(prefix)_api.swift")
        {
            self.logger.info("Wrote \(prefix)_api.swift")
        }
        let apiAsync = self.library.render(apiContext, withTemplate: "api_async")!
        if self.command.output, try self.format(apiAsync).writeIfChanged(
            toFile: "\(basePath)/\(prefix)_api+async.swift"
        ) {
            self.logger.info("Wrote \(prefix)_api+async.swift")
        }

        var shapesContext = try service.generateShapesContext()
        let errorContext = try service.generateErrorContext()
        if errorContext["errors"] != nil {
            shapesContext["errors"] = errorContext
        }

        let shapes = self.library.render(shapesContext, withTemplate: "shapes")!
        if self.command.output, try self.format(shapes).writeIfChanged(
            toFile: "\(basePath)/\(prefix)_shapes.swift"
        ) {
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
