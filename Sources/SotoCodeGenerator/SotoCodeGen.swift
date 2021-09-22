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
import SotoSmithy
import SotoSmithyAWS
import SwiftFormat

struct SotoCodeGen {
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

    init(command: SotoCodeGenCommand) throws {
        self.command = command
        self.library = try Templates.createLibrary()
        Smithy.registerAWSTraits()
        Smithy.registerTraitTypes(
            SotoInputShapeTrait.self,
            SotoOutputShapeTrait.self
        )
    }

    func getModelFiles() -> [String] {
        if let module = command.module {
            return Glob.entries(pattern: "\(self.command.inputFolder)/\(module)*.json")
        }
        return Glob.entries(pattern: "\(self.command.inputFolder)/*.json")
    }

    func getSmithyFiles() -> [String] {
        if let module = command.module {
            return Glob.entries(pattern: "\(self.command.inputFolder)/\(module)*.smithy")
        }
        return Glob.entries(pattern: "\(self.command.inputFolder)/*.smithy")
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
        let basePath = "\(command.outputFolder)/\(service.serviceName)/"
        try FileManager.default.createDirectory(atPath: basePath, withIntermediateDirectories: true)

        let apiContext = try service.generateServiceContext()
        let api = self.library.render(apiContext, withTemplate: "api")!
        if try self.format(api)
            .writeIfChanged(toFile: "\(basePath)\(service.serviceName)_API.swift")
        {
            print("Wrote: \(service.serviceName)_API.swift")
        }
        let apiAsync = self.library.render(apiContext, withTemplate: "api+async")!
        if self.command.output, try self.format(apiAsync).writeIfChanged(
            toFile: "\(basePath)/\(service.serviceName)_API+async.swift"
        ) {
            print("Wrote: \(service.serviceName)_API+async.swift")
        }

        let shapesContext = try service.generateShapesContext()
        let shapes = self.library.render(shapesContext, withTemplate: "shapes")!
        if self.command.output, try self.format(shapes).writeIfChanged(
            toFile: "\(basePath)/\(service.serviceName)_Shapes.swift"
        ) {
            print("Wrote: \(service.serviceName)_Shapes.swift")
        }

        let errorContext = try service.generateErrorContext()
        if errorContext["errors"] != nil {
            let errors = self.library.render(errorContext, withTemplate: "error")!
            if self.command.output, try self.format(errors).writeIfChanged(
                toFile: "\(basePath)/\(service.serviceName)_Error.swift"
            ) {
                print("Wrote: \(service.serviceName)_Error.swift")
            }
        }

        let paginatorContext = try service.generatePaginatorContext()
        if paginatorContext["paginators"] != nil {
            let paginators = self.library.render(paginatorContext, withTemplate: "paginator")!
            if self.command.output, try self.format(paginators).writeIfChanged(
                toFile: "\(basePath)/\(service.serviceName)_Paginator.swift"
            ) {
                print("Wrote: \(service.serviceName)_Paginator.swift")
            }
            let paginatorsAsync = self.library.render(paginatorContext, withTemplate: "paginator+async")!
            if self.command.output, try self.format(paginatorsAsync).writeIfChanged(
                toFile: "\(basePath)/\(service.serviceName)_Paginator+async.swift"
            ) {
                print("Wrote: \(service.serviceName)_Paginator+async.swift")
            }
        }

        let waiterContexts = try service.generateWaiterContexts()
        if waiterContexts["waiters"] != nil {
            let waiters = self.library.render(waiterContexts, withTemplate: "waiter")!
            if self.command.output, try self.format(waiters).writeIfChanged(
                toFile: "\(basePath)/\(service.serviceName)_Waiter.swift"
            ) {
                print("Wrote: \(service.serviceName)_Waiter.swift")
            }
            let waitersAsync = self.library.render(waiterContexts, withTemplate: "waiter+async")!
            if self.command.output, try self.format(waitersAsync).writeIfChanged(
                toFile: "\(basePath)/\(service.serviceName)_Waiter+async.swift"
            ) {
                print("Wrote: \(service.serviceName)_Waiter+async.swift")
            }
        }
        // print("Succesfully Generated \(service.serviceName)")
    }

    func generate() throws {
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
                    let service = try AwsService(model.value, endpoints: endpoints, outputHTMLComments: command.htmlComments)
                    if self.command.output {
                        try self.generateFiles(with: service)
                    }
                } catch {
                    print("\(model.key): \(error)")
                    exit(1)
                }
            }
        }

        group.wait()

        print("Code Generation took \(Int(-startTime.timeIntervalSinceNow)) seconds")
        print("Done.")
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
