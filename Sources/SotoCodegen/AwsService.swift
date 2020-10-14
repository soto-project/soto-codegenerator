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

import Foundation
import SotoSmithy
import SotoSmithyAWS

struct AwsService {
    var serviceName: String
    var apiContext: [String: Any]
    var shapesContext: [String: Any]
    var paginatorContext: [String: Any]
    var errorContext: [String: Any]

    init(_ model: SotoSmithy.Model) throws {
        guard let service = model.select(type: SotoSmithy.ServiceShape.self).first else { throw Error(reason: "No service object")}
        let serviceName = try Self.getServiceName(service.value, id: service.key)
        do {
            self.serviceName = serviceName
            self.apiContext = try Self.generateServiceContext(model, serviceName: self.serviceName)
            self.shapesContext = try Self.generateShapesContext(model, serviceName: self.serviceName)
            self.paginatorContext = try Self.generatePaginatorContext(model, serviceName: self.serviceName)
            self.errorContext = try Self.generateErrorContext(model, serviceName: self.serviceName)
        } catch let error as Error {
            throw Error(reason: "\(error) in service \(serviceName)")
        }
    }

    static func getTrait<T: StaticTrait>(from shape: SotoSmithy.Shape, trait: T.Type, id: ShapeId) throws -> T {
        guard let trait = shape.trait(type: T.self) else {
            throw Error(reason: "\(id) does not have a \(T.staticName) trait")
        }
        return trait
    }

    /// Return service name from API
    static func getServiceName(_ service: SotoSmithy.ServiceShape, id: ShapeId) throws -> String {
        let awsService = try getTrait(from: service, trait: AwsServiceTrait.self, id: id)

        // port of https://github.com/aws/aws-sdk-go-v2/blob/996478f06a00c31ee7e7b0c3ac6674ce24ba0120/private/model/api/api.go#L105
        let stripServiceNamePrefixes: [String] = ["Amazon", "AWS"]

        var serviceName = awsService.sdkId

        // Strip out prefix names not reflected in service client symbol names.
        for prefix in stripServiceNamePrefixes {
            serviceName.deletePrefix(prefix)
        }
        serviceName.removeCharacterSet(in: CharacterSet.alphanumerics.inverted)
        serviceName.removeWhitespaces()
        serviceName.capitalizeFirstLetter()

        return serviceName
    }

    /// Generate context for rendering service template
    static func generateServiceContext(_ model: SotoSmithy.Model, serviceName: String) throws -> [String: Any] {
        var context: [String: Any] = [:]
        guard let serviceEntry = model.select(type: SotoSmithy.ServiceShape.self).first else { throw Error(reason: "No service object")}
        let serviceId = serviceEntry.key
        let service = serviceEntry.value
        let awsService = try getTrait(from: service, trait: AwsServiceTrait.self, id: serviceId)
        let authSigV4 = try getTrait(from: service, trait: AwsAuthSigV4Trait.self, id: serviceId)
        let serviceProtocol = try getServiceProtocol(service)

        context["name"] = serviceName
        context["description"] = service.trait(type: DocumentationTrait.self).map { processDocs($0.value) }
        context["endpointPrefix"] = awsService.arnNamespace
        context["signingName"] = authSigV4.name
        context["protocol"] = serviceProtocol.output
        context["apiVersion"] = service.version
        if serviceProtocol is AwsProtocolsAwsJson1_0Trait || serviceProtocol is AwsProtocolsAwsJson1_1Trait {
            context["amzTarget"] = serviceId.shapeName
        }

        var operationContexts: [OperationContext] = []
        var streamingOperationContexts: [OperationContext] = []
        if let operations = service.operations {
            for operationId in operations {
                guard let operation = model.shape(for: operationId.target) as? OperationShape else {
                    throw Error(reason: "Operation \(operationId.target) does not exist")
                }
                let operationContext = try generateOperationContext(operation, operationName: operationId.target)
                operationContexts.append(operationContext)

                if let output = operation.output,
                   let outputShape = model.shape(for: output.target) as? StructureShape,
                   let payloadMember = getPayload(from: outputShape),
                   let payloadShape = model.shape(for: payloadMember.target),
                   payloadShape.trait(type: StreamingTrait.self) != nil,
                   payloadShape is BlobShape {
                    let operationContext = try generateOperationContext(operation, operationName: operationId.target, streaming: true)
                    streamingOperationContexts.append(operationContext)
                }
            }
        }

        context["operations"] = operationContexts.sorted { $0.funcName < $1.funcName }
        context["streamingOperations"] = streamingOperationContexts.sorted { $0.funcName < $1.funcName }
        context["logger"] = getSymbol(for: "Logger", from: "Logging", model: model, namespace: serviceId.namespace ?? "")
        return context
    }

    /// Generate paginator context
    static func generatePaginatorContext(_ model: SotoSmithy.Model, serviceName: String) throws -> [String: Any] {
        let paginatorOperations = try model.select(from: "operation [trait:paginated]")
        guard paginatorOperations.count > 0 else { return [:] }
        var context: [String: Any] = ["name": serviceName]
        let namespace = paginatorOperations.first?.key.namespace

        var paginatorContexts: [PaginatorContext] = []

        for operation in paginatorOperations {
            guard let operationShape = operation.value as? OperationShape else { continue }
            guard let paginatedTrait = operationShape.trait(type: PaginatedTrait.self) else { continue }
            guard let input = operationShape.input?.target else { continue }
            guard let inputShape = model.shape(for: input) as? StructureShape else { continue }
            guard let inputToken = paginatedTrait.inputToken else { continue }
            guard let inputMember = inputShape.members?[inputToken] else { continue }
            guard let inputMemberShape = model.shape(for: inputMember.target) else { continue }
            guard let inputMemberShapeName = inputMemberShape as? SotoOutput else { continue }
            guard let output = operationShape.output?.target else { continue }
            guard let outputShape = model.shape(for: output) as? StructureShape else { continue }
            guard let outputToken = paginatedTrait.outputToken else { continue }

            // construct array of input shape parameters to use in `usingPaginationToken` function
            var initParams: [String: String] = [:]
            for member in (inputShape.members ?? [:]) {
                initParams[member.key.toSwiftLabelCase()] = "self.\(member.key.toSwiftLabelCase())"
            }
            initParams[inputToken.toSwiftLabelCase()] = "token"
            let initParamsArray = initParams.map { "\($0.key): \($0.value)" }.sorted { $0.lowercased() < $1.lowercased() }

            paginatorContexts.append(
                PaginatorContext(
                    operation: try Self.generateOperationContext(operationShape, operationName: operation.key),
                    output: toKeyPath(token: outputToken, structure: outputShape),
                    moreResults: nil,
                    initParams: initParamsArray,
                    paginatorProtocol: "AWSPaginateToken",
                    tokenType: inputMemberShapeName.output
                )
            )
        }
        paginatorContexts.sort { $0.operation.funcName < $1.operation.funcName }
        if paginatorContexts.count > 0 {
            context["paginators"] = paginatorContexts
        }
        context["logger"] = getSymbol(for: "Logger", from: "Logging", model: model, namespace: namespace ?? "")
        return context
    }

    /// Generate the context information for outputting the error enums
    static func generateErrorContext(_ model: SotoSmithy.Model, serviceName: String) throws -> [String: Any] {
        let errorShapes = try model.select(from: "structure [trait:error]")
        guard errorShapes.count > 0 else { return [:] }
        
        var context: [String: Any] = [:]
        context["name"] = serviceName
        context["errorName"] = serviceName + "ErrorType"
        
        var errorContexts: [ErrorContext] = []
        for error in errorShapes {
            let name: String = error.key.shapeName
            errorContexts.append(ErrorContext(enum: name.toSwiftVariableCase(), string: name))
        }
        errorContexts.sort { $0.enum < $1.enum }
        if errorContexts.count > 0 {
            context["errors"] = errorContexts
        }
        return context
    }

    static func generateShapesContext(_ model: SotoSmithy.Model, serviceName: String) throws -> [String: Any] {
        var context: [String: Any] = [:]
        context["name"] = serviceName
        
        markInputOutputShapes(model)
        
        var shapeContexts: [[String: Any]] = []

        // generate enums
        let enums = try model.select(from: "[trait:enum]").map { $0 }.sorted { $0.key.shapeName < $1.key.shapeName }
        for e in enums {
            guard let enumContext = self.generateEnumContext(e.value, shapeName: e.key.shapeName) else { continue }
            let enumContextContainer: [String: Any] = ["enum": enumContext]
            shapeContexts.append(enumContextContainer)
        }
        
        // generate structures
        
        if shapeContexts.count > 0 {
            context["shapes"] = shapeContexts
        }
        return context
    }
    
    /// Generate context for rendering a single operation. Used by both `generateServiceContext` and `generatePaginatorContext`
    static func generateOperationContext(_ operation: OperationShape, operationName: ShapeId, streaming: Bool = false) throws -> OperationContext {
        let documentationTrait = operation.trait(type: DocumentationTrait.self)?.value
        let httpTrait = operation.trait(type: HttpTrait.self)
        let deprecatedTrait = operation.trait(type: DeprecatedTrait.self)
        return OperationContext(
            comment: documentationTrait.map{ processDocs($0) } ?? [],
            funcName: operationName.shapeName.toSwiftVariableCase(),
            inputShape: operation.input?.target.shapeName,
            outputShape: operation.output?.target.shapeName,
            name: operationName.shapeName,
            path: httpTrait?.uri ?? "/",
            httpMethod: httpTrait?.method ?? "POST",
            deprecated: deprecatedTrait?.message,
            streaming: streaming ? "ByteBuffer": nil,
            documentationUrl: nil
        )
    }

    /// Generate the context information for outputting an enum
    static func generateEnumContext(_ shape: Shape, shapeName: String) -> EnumContext? {
        guard let trait = shape.trait(type: EnumTrait.self) else { return nil }
        // Operations
        var valueContexts: [EnumMemberContext] = []
        let enumDefinitions = trait.value.sorted { $0.value < $1.value }
        for value in enumDefinitions {
            var key = value.value.lowercased()
                .replacingOccurrences(of: ".", with: "_")
                .replacingOccurrences(of: ":", with: "_")
                .replacingOccurrences(of: "-", with: "_")
                .replacingOccurrences(of: " ", with: "_")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "(", with: "_")
                .replacingOccurrences(of: ")", with: "_")
                .replacingOccurrences(of: "*", with: "all")

            if Int(String(key[key.startIndex])) != nil { key = "_" + key }

            var caseName = key.camelCased().reservedwordEscaped()
            if caseName.allLetterIsNumeric() {
                caseName = "\(shapeName.toSwiftVariableCase())\(caseName)"
            }
            valueContexts.append(EnumMemberContext(case: caseName, documentation: value.documentation, string: value.value))
        }

        return EnumContext(
            name: shapeName.toSwiftClassCase().reservedwordEscaped(),
            documentation: shape.trait(type: DocumentationTrait.self)?.value,
            values: valueContexts
        )
    }

    /// get service protocol from service
    static func getServiceProtocol(_ service: ServiceShape) throws -> AwsServiceProtocol {
        if let traits = service.traits {
            for trait in traits {
                if let protocolTrait = trait as? AwsServiceProtocol {
                    return protocolTrait
                }
            }
        }
        throw Error(reason: "No service protocol trait")
    }
    
    /// process documenation string
    static func processDocs(_ docs: String) -> [String] {
        return docs
            .tagStriped()
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: CharacterSet.whitespaces)}
            .compactMap { $0.isEmpty ? nil: $0 }
    }
    
    /// return symbol name with framework added if required  to avoid name clashes
    static func getSymbol(for symbol: String, from framework: String, model: SotoSmithy.Model, namespace: String) -> String {
        if model.shape(for: ShapeId(rawValue: "\(namespace)#\(symbol)")) != nil {
            return "\(framework).\(symbol)"
        }
        return symbol
    }

    /// return payload member of structure
    static func getPayload(from shape: StructureShape) -> MemberShape? {
        guard let members = shape.members else { return nil }
        for member in members.values {
            if member.trait(type: HttpPayloadTrait.self) != nil {
                return member
            }
        }
        return nil
    }

    /// mark up model with Soto traits for input and output shapes
    static func markInputOutputShapes(_ model: Model) {
        func addTrait<T: StaticTrait>(to shapeId: ShapeId, trait: T, depth: Int = 0) {
            guard let shape = model.shape(for: shapeId) else { return }
            // if shape already has trait then don't apply it again
            guard shape.trait(type: T.self) == nil else { return }
            shape.add(trait: trait)

            guard let structure = shape as? StructureShape else { return }
            guard let members = structure.members else { return }
            for member in members {
                addTrait(to: member.value.target, trait: trait, depth: depth + 1)
            }
        }

        for operation in model.select(type: OperationShape.self) {
            if let input = operation.value.input {
                addTrait(to: input.target, trait: SotoInputShapeTrait())
            }
            if let output = operation.value.output {
                addTrait(to: output.target, trait: SotoOutputShapeTrait())
            }
        }
    }
    
    /// convert paginator token to KeyPath
    static func toKeyPath(token: String, structure: StructureShape) -> String {
        var split = token.split(separator: ".")
        for i in 0..<split.count {
            // if string contains [-1] replace with '.last'.
            if let negativeIndexRange = split[i].range(of: "[-1]") {
                split[i].removeSubrange(negativeIndexRange)

                var replacement = "last"
                // if a member is mentioned after the '[-1]' then you need to add a ? to the keyPath
                if split.count > i + 1 {
                    replacement += "?"
                }
                split.insert(Substring(replacement), at: i + 1)
            }
        }
        // if output token is member of an optional struct add ? suffix
        let member = structure.members?[String(split[0])]
        if member?.trait(type: RequiredTrait.self) != nil,
            split.count > 1
        {
            split[0] += "?"
        }
        return split.map { String($0).toSwiftVariableCase() }.joined(separator: ".")
    }
}


extension AwsService {
    struct Error: Swift.Error {
        let reason: String
    }

    struct OperationContext {
        let comment: [String]
        let funcName: String
        let inputShape: String?
        let outputShape: String?
        let name: String
        let path: String
        let httpMethod: String
        let deprecated: String?
        let streaming: String?
        let documentationUrl: String?
    }

    struct PaginatorContext {
        let operation: OperationContext
        let output: String
        let moreResults: String?
        let initParams: [String]
        let paginatorProtocol: String
        let tokenType: String
    }

    struct ErrorContext {
        let `enum`: String
        let string: String
    }

    struct EnumContext {
        let name: String
        let documentation: String?
        let values: [EnumMemberContext]
    }

    struct EnumMemberContext {
        let `case`: String
        let documentation: String?
        let string: String
    }
}
