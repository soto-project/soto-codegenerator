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
    var model: Model
    var serviceName: String
    var serviceId: ShapeId
    var service: ServiceShape
    var serviceProtocol: AwsServiceProtocol
/*    var apiContext: [String: Any]
    var shapesContext: [String: Any]
    var paginatorContext: [String: Any]
    var errorContext: [String: Any]*/

    init(_ model: SotoSmithy.Model) throws {
        guard let service = model.select(type: SotoSmithy.ServiceShape.self).first else { throw Error(reason: "No service object")}

        self.model = model
        self.serviceId = service.key
        self.service = service.value
        self.serviceName = try Self.getServiceName(service.value, id: service.key)
        self.serviceProtocol = try Self.getServiceProtocol(service.value)
    }

    /// Return service name from API
    static func getServiceName(_ service: SotoSmithy.ServiceShape, id: ShapeId) throws -> String {
        guard let awsService = service.trait(type: AwsServiceTrait.self) else {
            throw Error(reason: "\(id) does not have a \(AwsServiceTrait.staticName) trait")
        }

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
    func generateServiceContext() throws -> [String: Any] {
        var context: [String: Any] = [:]
        guard let serviceEntry = model.select(type: SotoSmithy.ServiceShape.self).first else { throw Error(reason: "No service object")}
        let serviceId = serviceEntry.key
        let service = serviceEntry.value
        let awsService = try getTrait(from: service, trait: AwsServiceTrait.self, id: serviceId)
        let authSigV4 = try getTrait(from: service, trait: AwsAuthSigV4Trait.self, id: serviceId)
        let operations = try generateOperationContexts()

        context["name"] = serviceName
        context["description"] = service.trait(type: DocumentationTrait.self).map { processDocs($0.value) }
        context["endpointPrefix"] = awsService.arnNamespace
        context["signingName"] = authSigV4.name
        context["protocol"] = serviceProtocol.output
        context["apiVersion"] = service.version
        if serviceProtocol is AwsProtocolsAwsJson1_0Trait || serviceProtocol is AwsProtocolsAwsJson1_1Trait {
            context["amzTarget"] = serviceId.shapeName
        }
        if !model.select(with: TraitSelector<ErrorTrait>()).isEmpty {
            context["errorTypes"] = serviceName + "ErrorType"
        }
        context["middlewareClass"] = getMiddleware(for: service)
        //context["serviceEndpoints"]
        //context["regionalized"]
        //context["partitionEndpoints"]

        context["operations"] = operations.operations
        context["streamingOperations"] = operations.streamingOperations
        context["logger"] = getSymbol(for: "Logger", from: "Logging", model: model, namespace: serviceId.namespace ?? "")
        return context
    }

    /// Generate paginator context
    func generatePaginatorContext() throws -> [String: Any] {
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
            guard let output = operationShape.output?.target else { continue }
            guard let outputShape = model.shape(for: output) as? StructureShape else { continue }
            guard let outputToken = paginatedTrait.outputToken else { continue }
            let inputMemberShapeName = inputMember.output(model)

            // construct array of input shape parameters to use in `usingPaginationToken` function
            var initParams: [String: String] = [:]
            for member in (inputShape.members ?? [:]) {
                initParams[member.key.toSwiftLabelCase()] = "self.\(member.key.toSwiftLabelCase())"
            }
            initParams[inputToken.toSwiftLabelCase()] = "token"
            let initParamsArray = initParams.map { "\($0.key): \($0.value)" }.sorted { $0.lowercased() < $1.lowercased() }

            paginatorContexts.append(
                PaginatorContext(
                    operation: try generateOperationContext(operationShape, operationName: operation.key),
                    output: toKeyPath(token: outputToken, structure: outputShape),
                    moreResults: nil,
                    initParams: initParamsArray,
                    paginatorProtocol: "AWSPaginateToken",
                    tokenType: inputMemberShapeName
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
    func generateErrorContext() throws -> [String: Any] {
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

    /// Generate context for outputting Shapes
    func generateShapesContext() throws -> [String: Any] {
        var context: [String: Any] = [:]
        context["name"] = serviceName
        
        markInputOutputShapes(model)
        
        var shapeContexts: [[String: Any]] = []

        // generate enums
        let enums = try model.select(from: "[trait:enum]").map { (key: $0.key.shapeName, value: $0.value) }.sorted { $0.key < $1.key }
        for e in enums {
            guard let enumContext = self.generateEnumContext(e.value, shapeName: e.key) else { continue }
            shapeContexts.append(["enum": enumContext])
        }
        
        // generate structures
        let structures = model.select(type: StructureShape.self).map { (key: $0.key.shapeName, value: $0.value) }.sorted { $0.key < $1.key }
        for structure in structures {
            guard let shapeContext = self.generateStructureContext(structure.value, shapeName: structure.key) else { continue }
            shapeContexts.append(["struct": shapeContext])
        }

        // generate unions
        let unions = model.select(type: UnionShape.self).map { $0 }.map { (key: $0.key.shapeName, value: $0.value) }.sorted { $0.key < $1.key }
        for union in unions {
            guard let shapeContext = self.generateStructureContext(union.value, shapeName: union.key) else { continue }
            shapeContexts.append(["enumWithValues": shapeContext])
        }

        if shapeContexts.count > 0 {
            context["shapes"] = shapeContexts
        }
        return context
    }

    /// Generate list of operation and streaming operation contexts
    func generateOperationContexts() throws -> (operations: [OperationContext], streamingOperations: [OperationContext]) {
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
                   let payloadShape = model.shape(for: payloadMember.value.target),
                   payloadShape.trait(type: StreamingTrait.self) != nil,
                   payloadShape is BlobShape {
                    let operationContext = try generateOperationContext(operation, operationName: operationId.target, streaming: true)
                    streamingOperationContexts.append(operationContext)
                }
            }
        }
        return (
            operations: operationContexts.sorted { $0.funcName < $1.funcName },
            streamingOperations: streamingOperationContexts.sorted { $0.funcName < $1.funcName }
        )
    }

    /// Generate context for rendering a single operation. Used by both `generateServiceContext` and `generatePaginatorContext`
    func generateOperationContext(_ operation: OperationShape, operationName: ShapeId, streaming: Bool = false) throws -> OperationContext {
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
    func generateEnumContext(_ shape: Shape, shapeName: String) -> EnumContext? {
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

    /// Generate the context information for outputting a shape
    func generateStructureContext(_ shape: CollectionShape, shapeName: String) -> StructureContext? {
        let payload = getPayload(from: shape)
        guard let shapeProtocol = getShapeProtocol(shape, hasPayload: payload != nil) else { return nil }
        let contexts = generateMembersContexts(shape, shapeName: shapeName, typeIsEnum: shape is UnionShape)
        return StructureContext(
            object: "struct",
            name: shapeName.toSwiftClassCase(),
            shapeProtocol: shapeProtocol,
            payload: payload?.key.toSwiftLabelCase(),
            payloadOptions: nil,
            namespace: nil,
            encoding: [],
            members: contexts.members,
            awsShapeMembers: contexts.awsShapeMembers,
            codingKeys: contexts.codingKeys,
            validation: []
        )
    }

    struct MembersContexts {
        var members: [MemberContext] = []
        var awsShapeMembers: [MemberEncodingContext] = []
        var codingKeys: [CodingKeysContext] = []
    }
    /// generate shape members context
    func generateMembersContexts(_ shape: CollectionShape, shapeName: String, typeIsEnum: Bool) -> MembersContexts {
        var contexts = MembersContexts()
        guard let members = shape.members else { return contexts }
        let outputShape = shape.hasTrait(type: SotoOutputShapeTrait.self)
        let sortedMembers = members.map{ $0 }.sorted { $0.key.lowercased() < $1.key.lowercased() }
        for member in sortedMembers {
            // member context
            let memberContext = generateMemberContext(member.value, name: member.key, shapeName: shapeName, typeIsEnum: typeIsEnum)
            contexts.members.append(memberContext)
            // coding key context
            if let codingKeyContext = generateCodingKeyContext(member.value, name: member.key, outputShape: outputShape) {
                contexts.codingKeys.append(codingKeyContext)
            }
            // member encoding context
            if let memberEncodingContext = generateMemberEncodingContext(member.value, name: member.key) {
                contexts.awsShapeMembers.append(memberEncodingContext)
            }
        }
        return contexts
    }

    func generateMemberContext(_ member: MemberShape, name: String, shapeName: String, typeIsEnum: Bool) -> MemberContext {
        let required = member.hasTrait(type: RequiredTrait.self)
        let idempotencyToken = member.hasTrait(type: IdempotencyTokenTrait.self)
        let documentation = member.trait(type: DocumentationTrait.self)
        let defaultValue: String?
        if idempotencyToken == true {
            defaultValue = "\(shapeName.toSwiftClassCase()).idempotencyToken()"
        } else if !required {
            defaultValue = "nil"
        } else {
            defaultValue = nil
        }
        let type = member.output(model)
        return MemberContext(
            variable: name.toSwiftVariableCase(),
            parameter: name.toSwiftLabelCase(),
            required: member.hasTrait(type: RequiredTrait.self),
            default: defaultValue,
            propertyWrapper: nil,
            type: type + ((required || typeIsEnum) ? "" : "?"),
            comment: documentation.map { processMemberDocs($0.value) } ?? [],
            duplicate: false // NEED to catch this
        )
    }

    func generateMemberEncodingContext(_ member: MemberShape, name: String) -> MemberEncodingContext? {
        /*let isPayload = (shape.payload == name)
        var locationName: String? = member.locationName
        let location = member.location ?? .body

        if isPayload || location != .body, locationName == nil {
            locationName = name
        }
        // remove location if equal to body and name is same as variable name
        if location == .body, locationName == name.toSwiftLabelCase() || !isPayload {
            locationName = nil
        }
        guard locationName != nil else { return nil }
        return AWSShapeMemberContext(
            name: name.toSwiftLabelCase(),
            location: locationName.map { location.enumStringValue(named: $0) },
            locationName: locationName
        )*/
        if let headerTrait = member.trait(type: HttpHeaderTrait.self) {
            return MemberEncodingContext(name: name.toSwiftLabelCase(), location: ".header(locationName: \"\(headerTrait.value)\")")
        } else if let headerPrefixTrait = member.trait(type: HttpPrefixHeadersTrait.self) {
            return MemberEncodingContext(name: name.toSwiftLabelCase(), location: ".header(locationName: \"\(headerPrefixTrait.value)\")")
        } else if let queryTrait = member.trait(type: HttpQueryTrait.self) {
            return MemberEncodingContext(name: name.toSwiftLabelCase(), location: ".querystring(locationName: \"\(queryTrait.value)\")")
        } else if member.hasTrait(type: HttpLabelTrait.self) {
            let aliasTrait = member.trait(named: serviceProtocol.nameTrait.staticName) as? ProtocolAliasTrait
            return MemberEncodingContext(name: name.toSwiftLabelCase(), location: ".uri(locationName: \"\(aliasTrait?.aliasName ?? name)\")")
        } else if member.hasTrait(type: HttpResponseCodeTrait.self) {
            return MemberEncodingContext(name: name.toSwiftLabelCase(), location: ".statusCode")
        } else if member.hasTrait(type: HttpPayloadTrait.self), !(model.shape(for: member.target) is BlobShape) {
            let aliasTrait = member.trait(named: serviceProtocol.nameTrait.staticName) as? ProtocolAliasTrait
            let payloadName = aliasTrait?.aliasName ?? name
            let swiftLabelName = name.toSwiftLabelCase()
            if swiftLabelName != payloadName {
                return MemberEncodingContext(name: swiftLabelName, location: ".body(locationName: \"\(payloadName)\")")
            }
        }
        return nil
    }
    
    func generateCodingKeyContext(_ member: MemberShape, name: String, outputShape: Bool) -> CodingKeysContext? {
        guard outputShape ||
                (!member.hasTrait(type: HttpHeaderTrait.self) &&
                    !member.hasTrait(type: HttpPrefixHeadersTrait.self) &&
                    !member.hasTrait(type: HttpQueryTrait.self) &&
                    !member.hasTrait(type: HttpLabelTrait.self) &&
                    !(member.hasTrait(type: HttpPayloadTrait.self) && model.shape(for: member.target) is BlobShape)) else {
            return nil
        }
        var codingKey: String = name
        if let aliasTrait = member.trait(named: serviceProtocol.nameTrait.staticName) as? ProtocolAliasTrait {
            codingKey = aliasTrait.aliasName
        }
        return CodingKeysContext(variable: name.toSwiftVariableCase(), codingKey: codingKey, duplicate: false)
    }

    func getTrait<T: StaticTrait>(from shape: SotoSmithy.Shape, trait: T.Type, id: ShapeId) throws -> T {
        guard let trait = shape.trait(type: T.self) else {
            throw Error(reason: "\(id) does not have a \(T.staticName) trait")
        }
        return trait
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
    func processDocs(_ docs: String) -> [String.SubSequence] {
        return docs
            .tagStriped()
            .replacingOccurrences(of: "\n +", with: " ", options: .regularExpression, range: nil)
            .split(separator: "\n")
            .compactMap { $0.isEmpty ? nil: $0 }
    }

    /// process documenation string
    func processMemberDocs(_ docs: String) -> [String.SubSequence] {
        return docs
            .tagStriped()
            .replacingOccurrences(of: "\n +", with: " ", options: .regularExpression, range: nil)
            .split(separator: "\n")
            .compactMap { $0.isEmpty ? nil: $0 }
    }

    /// return middleware name given a service name
    func getMiddleware(for service: ServiceShape) -> String? {
        guard let awsServiceTrait = service.trait(type: AwsServiceTrait.self) else { return nil }
        switch awsServiceTrait.sdkId {
        case "API Gateway":
            return "APIGatewayMiddleware()"
        case "Glacier":
            return "GlacierRequestMiddleware(apiVersion: \"\(service.version)\")"
        case "S3":
            return "S3RequestMiddleware()"
        case "S3 Control":
            return "S3ControlMiddleware()"
        default:
            return nil
        }
    }

    /// return symbol name with framework added if required  to avoid name clashes
    func getSymbol(for symbol: String, from framework: String, model: SotoSmithy.Model, namespace: String) -> String {
        if model.shape(for: ShapeId(rawValue: "\(namespace)#\(symbol)")) != nil {
            return "\(framework).\(symbol)"
        }
        return symbol
    }

    /// return payload member of structure
    func getPayload(from shape: CollectionShape) -> (key: String, value: MemberShape)? {
        guard let members = shape.members else { return nil }
        for member in members {
            if member.value.trait(type: HttpPayloadTrait.self) != nil {
                return member
            }
        }
        return nil
    }

    /// mark up model with Soto traits for input and output shapes
    func markInputOutputShapes(_ model: Model) {
        func addTrait<T: StaticTrait>(to shapeId: ShapeId, trait: T) {
            guard let shape = model.shape(for: shapeId) else { return }
            // if shape already has trait then don't apply it again
            guard shape.trait(type: T.self) == nil else { return }
            shape.add(trait: trait)

            if let structure = shape as? CollectionShape {
                guard let members = structure.members else { return }
                for member in members {
                    addTrait(to: member.value.target, trait: trait)
                }
            } else if let list = shape as? ListShape {
                addTrait(to: list.member.target, trait: trait)
            } else if let set = shape as? SetShape {
                addTrait(to: set.member.target, trait: trait)
            } else if let map = shape as? MapShape {
                addTrait(to: map.key.target, trait: trait)
                addTrait(to: map.value.target, trait: trait)
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
    func toKeyPath(token: String, structure: StructureShape) -> String {
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

    /// get protocol needed for shape
    func getShapeProtocol(_ shape: Shape, hasPayload: Bool) -> String? {
        let usedInInput = shape.hasTrait(type: SotoInputShapeTrait.self)
        let usedInOutput = shape.hasTrait(type: SotoOutputShapeTrait.self)
        var shapeProtocol: String
        if usedInInput {
            shapeProtocol = "AWSEncodableShape"
            if usedInOutput {
                shapeProtocol += " & AWSDecodableShape"
            }
        } else if usedInOutput {
            shapeProtocol = "AWSDecodableShape"
        } else {
            return nil
        }
        if hasPayload {
            shapeProtocol += " & AWSShapeWithPayload"
        }
        return shapeProtocol
    }
}

protocol EncodingPropertiesContext {}

extension AwsService {
    struct Error: Swift.Error {
        let reason: String
    }

    struct OperationContext {
        let comment: [String.SubSequence]
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

    struct ArrayEncodingPropertiesContext: EncodingPropertiesContext {
        let name: String
        let member: String
    }

    struct DictionaryEncodingPropertiesContext: EncodingPropertiesContext {
        let name: String
        let entry: String?
        let key: String
        let value: String
    }

    struct MemberContext {
        let variable: String
        let parameter: String
        let required: Bool
        let `default`: String?
        let propertyWrapper: String?
        let type: String
        let comment: [String.SubSequence]
        var duplicate: Bool
    }

    struct MemberEncodingContext {
        let name: String
        let location: String?
    }

    class ValidationContext {
        let name: String
        let shape: Bool
        let required: Bool
        let reqs: [String: Any]
        let member: ValidationContext?
        let key: ValidationContext?
        let value: ValidationContext?

        init(
            name: String,
            shape: Bool = false,
            required: Bool = true,
            reqs: [String: Any] = [:],
            member: ValidationContext? = nil,
            key: ValidationContext? = nil,
            value: ValidationContext? = nil
        ) {
            self.name = name
            self.shape = shape
            self.required = required
            self.reqs = reqs
            self.member = member
            self.key = key
            self.value = value
        }
    }

    struct CodingKeysContext {
        let variable: String
        let codingKey: String
        var duplicate: Bool
    }

    struct StructureContext {
        let object: String
        let name: String
        let shapeProtocol: String
        let payload: String?
        var payloadOptions: String?
        let namespace: String?
        let encoding: [EncodingPropertiesContext]
        let members: [MemberContext]
        let awsShapeMembers: [MemberEncodingContext]
        let codingKeys: [CodingKeysContext]
        let validation: [ValidationContext]
    }
}
