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

import Dispatch
import Foundation
import SotoSmithy
import SotoSmithyAWS
import PathKit
import Stencil

struct SotoCodeGen {
    let environment: Environment
    let command: SotoCodeGenCommand

    init(command: SotoCodeGenCommand) {
        let path = Bundle.module.resourcePath!
        self.environment = Stencil.Environment(loader: FileSystemLoader(paths: [Path(path)]))
        self.command = command
        Smithy.registerAWSTraits()
        Smithy.registerTraitTypes(
            SotoPatchEnumTrait.self,
            SotoPatchNameTrait.self,
            SotoInputShapeTrait.self,
            SotoOutputShapeTrait.self
        )
    }

    func getModelFiles() -> [String] {
        if let module = command.module {
            return Glob.entries(pattern: "\(self.command.inputFolder)/\(module)*.json")
        }
        return Glob.entries(pattern: "\(self.command.inputFolder)/*")
    }

/*    func loadEndpointJSON() throws -> Endpoints {
        let data = try Data(contentsOf: URL(fileURLWithPath: "\(command.inputFolder)/endpoints/endpoints.json"))
        return try JSONDecoder().decode(Endpoints.self, from: data)
    }*/

    func loadModelJSON() throws -> [SotoSmithy.Model] {
        let modelFiles = self.getModelFiles()

        return try modelFiles.map {
            let data = try Data(contentsOf: URL(fileURLWithPath: $0))
            let model = try Smithy().decode(from: data)
            try model.validate()
            return model
        }
    }

    /// Generate service files from AWSService
    /// - Parameter codeGenerator: service generated from JSON
    func generateFiles(with service: AwsService) throws {

        let basePath = "\(command.outputFolder)/\(service.serviceName)/"
        try FileManager.default.createDirectory(atPath: basePath, withIntermediateDirectories: true)

        let apiContext = try service.generateServiceContext()
        if try self.environment.renderTemplate(name: "api.stencil", context: apiContext).writeIfChanged(
            toFile: "\(basePath)/\(service.serviceName)_API.swift"
        ) {
            print("Wrote: \(service.serviceName)_API.swift")
        }

        let shapesContext = try service.generateShapesContext()
        if try self.environment.renderTemplate(name: "shapes.stencil", context: shapesContext).writeIfChanged(
            toFile: "\(basePath)/\(service.serviceName)_Shapes.swift"
        ) {
            print("Wrote: \(service.serviceName)_Shapes.swift")
        }

        let errorContext = try service.generateErrorContext()
        if errorContext["errors"] != nil {
            if try self.environment.renderTemplate(name: "error.stencil", context: errorContext).writeIfChanged(
                toFile: "\(basePath)/\(service.serviceName)_Error.swift"
            ) {
                print("Wrote: \(service.serviceName)_Error.swift")
            }
        }

        let paginatorContext = try service.generatePaginatorContext()
        if paginatorContext["paginators"] != nil {
            if try self.environment.renderTemplate(name: "paginator.stencil", context: paginatorContext).writeIfChanged(
                toFile: "\(basePath)/\(service.serviceName)_Paginator.swift"
            ) {
                print("Wrote: \(service.serviceName)_Paginator.swift")
            }
        }
        //print("Succesfully Generated \(service.serviceName)")
    }

    func generate() throws {
        let startTime = Date()

        // load JSON
        //let endpoints = try loadEndpointJSON()
        let models = try loadModelJSON()
        let group = DispatchGroup()

        models.forEach { model in
            group.enter()

            DispatchQueue.global().sync {
                defer { group.leave() }
                do {
                    let service = try AwsService(model)
                    if self.command.output {
                        try self.generateFiles(with: service)
                    }
                } catch {
                    print("\(error)")
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
