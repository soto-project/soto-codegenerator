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
    var serviceEndpointPrefix: String
    var serviceId: ShapeId
    var service: ServiceShape
    var serviceProtocolTrait: AwsServiceProtocol
    var endpoints: Endpoints
    var operations: [ShapeId: OperationShape]

    init(_ model: SotoSmithy.Model, endpoints: Endpoints) throws {
        guard let service = model.select(type: SotoSmithy.ServiceShape.self).first else { throw Error(reason: "No service object")}

        self.model = model
        self.serviceId = service.key
        self.service = service.value
        self.serviceName = try Self.getServiceName(service.value, id: service.key)
        self.serviceEndpointPrefix = try Self.getServiceEndpointPrefix(service: service.value, id: service.key)
        self.serviceProtocolTrait = try Self.getServiceProtocol(service.value)

        try model.patch(serviceName: serviceName)

        self.operations = Self.getOperations(service.value, model: model)
        
        self.endpoints = endpoints
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

    /// return service name used in endpoint. Uses filename of Smithy file
    static func getServiceEndpointPrefix(service: SotoSmithy.ServiceShape, id: ShapeId) throws -> String {
        let awsService = try Self.getTrait(from: service, trait: AwsServiceTrait.self, id: id)
        return awsService.arnNamespace
    }
    
    /// Generate context for rendering service template
    func generateServiceContext() throws -> [String: Any] {
        var context: [String: Any] = [:]
        guard let serviceEntry = model.select(type: SotoSmithy.ServiceShape.self).first else { throw Error(reason: "No service object")}
        let serviceId = serviceEntry.key
        let service = serviceEntry.value
        let authSigV4 = try Self.getTrait(from: service, trait: AwsAuthSigV4Trait.self, id: serviceId)
        let operations = try generateOperationContexts()

        context["name"] = serviceName
        context["description"] = service.trait(type: DocumentationTrait.self).map { processDocs($0.value) }
        context["endpointPrefix"] = self.serviceEndpointPrefix
        if authSigV4.name != self.serviceEndpointPrefix {
            context["signingName"] = authSigV4.name
        }
        context["protocol"] = serviceProtocolTrait.output
        context["apiVersion"] = service.version
        if serviceProtocolTrait is AwsProtocolsAwsJson1_0Trait || serviceProtocolTrait is AwsProtocolsAwsJson1_1Trait {
            context["amzTarget"] = serviceId.shapeName
        }
        if !model.select(with: TraitSelector<ErrorTrait>()).isEmpty {
            context["errorTypes"] = serviceName + "ErrorType"
        }
        context["middlewareClass"] = getMiddleware(for: service)
        
        let endpoints = self.getServiceEndpoints()
            .sorted { $0.key < $1.key }
            .map { "\"\($0.key)\": \"\($0.value)\"" }
        if endpoints.count > 0 {
            context["serviceEndpoints"] = endpoints
        }
        
        let isRegionalized: Bool? = self.endpoints.partitions.reduce(nil) {
            guard let regionalized = $1.services[self.serviceEndpointPrefix]?.isRegionalized else { return $0 }
            return ($0 ?? false) || regionalized
        }
        context["regionalized"] = isRegionalized ?? true
        if isRegionalized != true {
            context["partitionEndpoints"] = self.getPartitionEndpoints()
                .map { (partition: $0.key, endpoint: $0.value.endpoint, region: $0.value.region) }
                .sorted { $0.partition < $1.partition }
                .map { ".\($0.partition.toSwiftRegionEnumCase()): (endpoint: \"\($0.endpoint)\", region: .\($0.region.rawValue.toSwiftRegionEnumCase()))" }
        }

        context["operations"] = operations.operations
        context["streamingOperations"] = operations.streamingOperations
        context["logger"] = getSymbol(for: "Logger", from: "Logging", model: model, namespace: serviceId.namespace ?? "")
        return context
    }

    /// Generate paginator context
    func generatePaginatorContext() throws -> [String: Any] {
        let paginatorOperations = try model.select(from: "operation [trait|paginated]")
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
        let errorShapes = try model.select(from: "structure [trait|error]")
        guard errorShapes.count > 0 else { return [:] }
        
        var context: [String: Any] = [:]
        context["name"] = serviceName
        context["errorName"] = serviceName + "ErrorType"
        
        var errorContexts: [ErrorContext] = []
        for error in errorShapes {
            let name: String = error.key.shapeName
            let documentationTrait = error.value.trait(type: DocumentationTrait.self)
            let errorContext = ErrorContext(
                enum: name.toSwiftVariableCase(),
                string: name,
                comment: documentationTrait.map{ processDocs($0.value) } ?? []
            )
            errorContexts.append(errorContext)
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
        let enums = try model.select(from: "[trait|enum]").map { (key: $0.key.shapeName, value: $0.value) }.sorted { $0.key < $1.key }
        for e in enums {
            guard let enumContext = self.generateEnumContext(e.value, shapeName: e.key) else { continue }
            shapeContexts.append(["enum": enumContext])
        }
        
        // generate structures
        let structures = model.select(type: StructureShape.self).sorted { $0.key.shapeName < $1.key.shapeName }
        for structure in structures {
            guard let shapeContext = self.generateStructureContext(structure.value, shapeId: structure.key) else { continue }
            shapeContexts.append(["struct": shapeContext])
        }

        // generate unions
        let unions = model.select(type: UnionShape.self).map { (key: $0.key.shapeName, value: $0) }.sorted { $0.key < $1.key }
        for union in unions {
            guard let shapeContext = self.generateStructureContext(union.value.value, shapeId: union.value.key) else { continue }
            // don't create an enum with values if there is only one member
            if shapeContext.members.count > 1 {
                shapeContexts.append(["enumWithValues": shapeContext])
            } else {
                shapeContexts.append(["struct": shapeContext])
            }
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
        let operations = self.operations
        for operation in operations {
            let operationContext = try generateOperationContext(operation.value, operationName: operation.key)
            operationContexts.append(operationContext)

            if let output = operation.value.output,
               let outputShape = model.shape(for: output.target) as? StructureShape,
               let payloadMember = getPayloadMember(from: outputShape),
               let payloadShape = model.shape(for: payloadMember.value.target),
               payloadShape.trait(type: StreamingTrait.self) != nil,
               payloadShape is BlobShape {
                let operationContext = try generateOperationContext(operation.value, operationName: operation.key, streaming: true)
                streamingOperationContexts.append(operationContext)
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
            documentationUrl: nil //operation.trait(type: ExternalDocumentationTrait.self)?.value["API Reference"]
        )
    }

    /// Generate the context information for outputting an enum
    func generateEnumContext(_ shape: Shape, shapeName: String) -> EnumContext? {
        guard let trait = shape.trait(type: EnumTrait.self) else { return nil }
        let usedInInput = shape.hasTrait(type: SotoInputShapeTrait.self)
        let usedInOutput = shape.hasTrait(type: SotoOutputShapeTrait.self)
        guard usedInInput || usedInOutput else { return nil }
        
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
            valueContexts.append(EnumMemberContext(case: caseName, documentation: nil/*value.documentation*/, string: value.value))
        }
        return EnumContext(
            name: shapeName.toSwiftClassCase().reservedwordEscaped(),
            documentation: shape.trait(type: DocumentationTrait.self)?.value,
            values: valueContexts,
            isExtensible: shape.hasTrait(type: SotoExtensibleEnumTrait.self)
        )
    }

    /// Generate the context information for outputting a shape
    func generateStructureContext(_ shape: CollectionShape, shapeId: ShapeId) -> StructureContext? {
        let shapeName = shapeId.shapeName
        var shapePayloadOptions: [String] = []
        var xmlNamespace: String?
        let payloadMember = getPayloadMember(from: shape)
        
        guard let shapeProtocol = getShapeProtocol(shape, hasPayload: payloadMember != nil) else { return nil }
        
        let contexts = generateMembersContexts(shape, shapeName: shapeName, typeIsEnum: shape is UnionShape)
        
        // get payload options
        if let payloadMember = payloadMember, let payload = model.shape(for: payloadMember.value.target) {
            if payload is BlobShape {
                shapePayloadOptions.append("raw")
                if payload.hasTrait(type: StreamingTrait.self) {
                    shapePayloadOptions.append("allowStreaming")
                    /*if !payload.hasTrait(type: RequiredTrait.self) {
                        shapePayloadOptions.append("allowChunkedStreaming")
                    }*/
                }
            }
        }
        if serviceProtocolTrait is AwsProtocolsRestXmlTrait {
            xmlNamespace = shape.trait(type: XmlNamespaceTrait.self)?.uri ?? service.trait(type: XmlNamespaceTrait.self)?.uri
        }
        let recursive = doesShapeHaveRecursiveOwnReference(shape, shapeId: shapeId)
        
        return StructureContext(
            object: recursive ? "class": "struct",
            name: shapeName.toSwiftClassCase(),
            shapeProtocol: shapeProtocol,
            payload: payloadMember?.key.toSwiftLabelCase(),
            payloadOptions: shapePayloadOptions.count > 0 ? shapePayloadOptions.map { ".\($0)" }.joined(separator: ", ") : nil,
            namespace: xmlNamespace,
            isEncodable: shape.hasTrait(type: SotoInputShapeTrait.self),
            isDecodable: shape.hasTrait(type: SotoOutputShapeTrait.self),
            encoding: contexts.encoding,
            members: contexts.members,
            awsShapeMembers: contexts.awsShapeMembers,
            codingKeys: contexts.codingKeys,
            validation: contexts.validation
        )
    }

    struct MembersContexts {
        var members: [MemberContext] = []
        var awsShapeMembers: [MemberEncodingContext] = []
        var codingKeys: [CodingKeysContext] = []
        var validation: [ValidationContext] = []
        var encoding: [EncodingPropertiesContext] = []
    }
    
    /// generate shape members context
    func generateMembersContexts(_ shape: CollectionShape, shapeName: String, typeIsEnum: Bool) -> MembersContexts {
        var contexts = MembersContexts()
        guard let members = shape.members else { return contexts }
        let isOutputShape = shape.hasTrait(type: SotoOutputShapeTrait.self)
        let isInputShape = shape.hasTrait(type: SotoInputShapeTrait.self)
        let sortedMembers = members.map{ $0 }.sorted { $0.key.lowercased() < $1.key.lowercased() }
        for member in sortedMembers {
            // member context
            let memberContext = generateMemberContext(member.value, name: member.key, shapeName: shapeName, typeIsEnum: typeIsEnum)
            contexts.members.append(memberContext)
            // coding key context
            if let codingKeyContext = generateCodingKeyContext(member.value, name: member.key, isOutputShape: isOutputShape) {
                contexts.codingKeys.append(codingKeyContext)
            }
            // member encoding context
            if let memberEncodingContext = generateMemberEncodingContext(
                member.value,
                name: member.key,
                isPropertyWrapper: memberContext.propertyWrapper != nil && isInputShape
            ) {
                contexts.awsShapeMembers.append(memberEncodingContext)
            }
            // validation context
            if isInputShape {
                if let validationContext = generateValidationContext(member.value, name: member.key) {
                    contexts.validation.append(validationContext)
                }
            }
            if let encodingPropertyContex = generateEncodingPropertyContext(member.value, name: member.key) {
                contexts.encoding.append(encodingPropertyContex)
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
            propertyWrapper: generatePropertyWrapper(member, name: name, required: required),
            type: type + ((required || typeIsEnum) ? "" : "?"),
            comment: documentation.map { processMemberDocs($0.value) } ?? [],
            duplicate: false // NEED to catch this
        )
    }

    func generateMemberEncodingContext(_ member: MemberShape, name: String, isPropertyWrapper: Bool) -> MemberEncodingContext? {
        // if header
        if let headerTrait = member.trait(type: HttpHeaderTrait.self) {
            let name = isPropertyWrapper ? "_\(name.toSwiftLabelCase())" : name.toSwiftLabelCase()
            return MemberEncodingContext(name: name, location: ".header(locationName: \"\(headerTrait.value)\")")
        // if prefix header
        } else if let headerPrefixTrait = member.trait(type: HttpPrefixHeadersTrait.self) {
            let name = isPropertyWrapper ? "_\(name.toSwiftLabelCase())" : name.toSwiftLabelCase()
            return MemberEncodingContext(name: name, location: ".header(locationName: \"\(headerPrefixTrait.value)\")")
        // if query string
        } else if let queryTrait = member.trait(type: HttpQueryTrait.self) {
            let name = isPropertyWrapper ? "_\(name.toSwiftLabelCase())" : name.toSwiftLabelCase()
            return MemberEncodingContext(name: name, location: ".querystring(locationName: \"\(queryTrait.value)\")")
        // if part of URL
        } else if member.hasTrait(type: HttpLabelTrait.self) {
            let name = isPropertyWrapper ? "_\(name.toSwiftLabelCase())" : name.toSwiftLabelCase()
            let aliasTrait = member.trait(named: serviceProtocolTrait.nameTrait.staticName) as? AliasTrait
            return MemberEncodingContext(name: name, location: ".uri(locationName: \"\(aliasTrait?.alias ?? name)\")")
        // if response status code
        } else if member.hasTrait(type: HttpResponseCodeTrait.self) {
            let name = isPropertyWrapper ? "_\(name.toSwiftLabelCase())" : name.toSwiftLabelCase()
            return MemberEncodingContext(name: name, location: ".statusCode")
        // if payload and not a blob
        } else if member.hasTrait(type: HttpPayloadTrait.self), !(model.shape(for: member.target) is BlobShape) {
            let aliasTrait = member.traits?.first(where: {$0 is AliasTrait}) as? AliasTrait
            let payloadName = aliasTrait?.alias ?? name
            let swiftLabelName = name.toSwiftLabelCase()
            if swiftLabelName != payloadName {
                let name = isPropertyWrapper ? "_\(name.toSwiftLabelCase())" : name.toSwiftLabelCase()
                return MemberEncodingContext(name: name, location: ".body(locationName: \"\(payloadName)\")")
            }
        }
        return nil
    }
    
    func generateCodingKeyContext(_ member: MemberShape, name: String, isOutputShape: Bool) -> CodingKeysContext? {
        guard isOutputShape ||
                (!member.hasTrait(type: HttpHeaderTrait.self) &&
                    !member.hasTrait(type: HttpPrefixHeadersTrait.self) &&
                    !member.hasTrait(type: HttpQueryTrait.self) &&
                    !member.hasTrait(type: HttpLabelTrait.self) &&
                    !(member.hasTrait(type: HttpPayloadTrait.self) && model.shape(for: member.target) is BlobShape)) else {
            return nil
        }
        var codingKey: String = name
        if let aliasTrait = member.traits?.first(where: {$0 is AliasTrait}) as? AliasTrait {
            codingKey = aliasTrait.alias
        }
        return CodingKeysContext(variable: name.toSwiftVariableCase(), codingKey: codingKey, duplicate: false)
    }

    /// Generate array/dictionary encoding contexts
    func generateEncodingPropertyContext(_ member: MemberShape, name: String) -> EncodingPropertiesContext? {
        guard let memberShape = model.shape(for: member.target) else { return nil }
        switch memberShape {
        case let list as ListShape:
            guard self.serviceProtocolTrait.requiresCollectionCoders else { return nil }
            let memberName = getListEntryName(member: member, list: list)
            guard let validMemberName = memberName, validMemberName != "member" else { return nil }
            return ArrayEncodingPropertiesContext(name: self.encodingName(name), member: validMemberName)
        case let map as MapShape:
            guard self.serviceProtocolTrait.requiresCollectionCoders else { return nil }
            let names = getMapEntryNames(member: member, map: map)
            guard names.entry != "entry" || names.key != "key" || names.value != "value" else { return nil }
            return DictionaryEncodingPropertiesContext(name: self.encodingName(name), entry: names.entry, key: names.key, value: names.value)
        default:
            return nil
        }
    }

    func generatePropertyWrapper(_ member: MemberShape, name: String, required: Bool) -> String? {
        let memberShape = model.shape(for: member.target)
        let codingWrapper: String
        if required {
            codingWrapper = "@CustomCoding"
        } else {
            codingWrapper = "@OptionalCustomCoding"
        }

        // if not located in body don't generate collection encoding property wrapper
        /*if let location = member.location {
            guard case .body = location else { return nil }
        }*/

        switch memberShape {
        case let list as ListShape:
            guard self.serviceProtocolTrait.requiresCollectionCoders else { return nil }
            let memberName = getListEntryName(member: member, list: list)
            guard let validMemberName = memberName else { return nil }
            if validMemberName == "member" {
                return "\(codingWrapper)<StandardArrayCoder>"
            } else {
                return "\(codingWrapper)<ArrayCoder<\(self.encodingName(name)), \(list.member.output(model))>>"
            }
        case let map as MapShape:
            guard self.serviceProtocolTrait.requiresCollectionCoders else { return nil }
            let names = getMapEntryNames(member: member, map: map)
            if names.entry == "entry", names.key == "key", names.value == "value" {
                return "\(codingWrapper)<StandardDictionaryCoder>"
            } else {
                return "\(codingWrapper)<DictionaryCoder<\(self.encodingName(name)), \(map.key.output(model)), \(map.value.output(model))>>"
            }
        case let timestamp as TimestampShape:
            if let formatTrait = timestamp.trait(type: TimestampFormatTrait.self) {
                switch formatTrait.value {
                case .datetime:
                    return "\(codingWrapper)<ISO8601DateCoder>"
                case .epochSeconds:
                    return "\(codingWrapper)<UnixEpochDateCoder>"
                case .httpDate:
                    return "\(codingWrapper)<HTTPHeaderDateCoder>"
                }
            } else if member.hasTrait(type: HttpHeaderTrait.self) {
                return "\(codingWrapper)<HTTPHeaderDateCoder>"
            }
            return nil
        default:
            return nil
        }
    }

    func generateValidationContext(_ member: MemberShape, name: String) -> ValidationContext? {

        func generateValidationContext(_ shapeId: ShapeId, name: String, required: Bool, container: Bool = false, alreadyProcessed: Set<ShapeId>) -> ValidationContext? {
            guard !alreadyProcessed.contains(shapeId) else { return nil }
            guard let shape = model.shape(for: shapeId) else { return nil }
            guard !shape.hasTrait(type: EnumTrait.self) else { return nil }
            
            var requirements: [String: Any] = [:]
            if let lengthTrait = shape.trait(type: LengthTrait.self) {
                if let min = lengthTrait.min, min > 0 {
                    requirements["min"] = min
                }
                requirements["max"] = lengthTrait.max
            }
            if let rangeTrait = shape.trait(type: RangeTrait.self) {
                if shape is FloatShape || shape is DoubleShape || shape is BigDecimalShape {
                    requirements["min"] = rangeTrait.min
                    requirements["max"] = rangeTrait.max
                } else {
                    requirements["min"] = rangeTrait.min.map { Int64($0) }
                    requirements["max"] = rangeTrait.max.map { Int64($0) }
                }
            }
            if let patternTrait = shape.trait(type: PatternTrait.self) {
                requirements["pattern"] = "\"\(patternTrait.value.addingBackslashEncoding())\""
            }
            
            var listMember: MemberShape? = nil
            if let list = shape as? ListShape {
                listMember = list.member
            } else if let set = shape as? SetShape {
                listMember = set.member
            }
            if let listMember = listMember {
                // validation code doesn't support containers inside containers. Only service affected by this is SSM
                if !container {
                    if let memberValidationContext = generateValidationContext(
                        listMember.target,
                        name: name,
                        required: true,
                        container: true,
                        alreadyProcessed: alreadyProcessed
                    ) {
                        return ValidationContext(
                            name: name.toSwiftVariableCase(),
                            required: required,
                            reqs: requirements,
                            member: memberValidationContext
                        )
                    }
                }
            }
            
            if let map = shape as? MapShape {
                // validation code doesn't support containers inside containers. Only service affected by this is SSM
                if !container {
                    let keyValidationContext = generateValidationContext(
                        map.key.target,
                        name: name,
                        required: true,
                        container: true,
                        alreadyProcessed: alreadyProcessed
                    )
                    let valueValidationContext = generateValidationContext(
                        map.value.target,
                        name: name,
                        required: true,
                        container: true,
                        alreadyProcessed: alreadyProcessed
                    )
                    if keyValidationContext != nil || valueValidationContext != nil {
                        return ValidationContext(
                            name: name.toSwiftVariableCase(),
                            required: required,
                            reqs: requirements,
                            key: keyValidationContext,
                            value: valueValidationContext
                        )
                    }
                }
            }
            
            if let collection = shape as? CollectionShape, let members = collection.members {
                for member in members {
                    let memberRequired = member.value.hasTrait(type: RequiredTrait.self)
                    var alreadyProcessed2 = alreadyProcessed
                    alreadyProcessed2.insert(shapeId)
                    if generateValidationContext(
                        member.value.target,
                        name: member.key,
                        required: memberRequired,
                        container: false,
                        alreadyProcessed: alreadyProcessed2
                    ) != nil {
                        return ValidationContext(name: name.toSwiftVariableCase(), shape: true, required: required)
                    }
                }

            }
            if requirements.count > 0 {
                return ValidationContext(name: name.toSwiftVariableCase(), reqs: requirements)
            }
            return nil
        }
        
        let required = member.hasTrait(type: RequiredTrait.self)
        return generateValidationContext(member.target, name: name, required: required, container: false, alreadyProcessed: [])
    }
    
    static func getTrait<T: StaticTrait>(from shape: SotoSmithy.Shape, trait: T.Type, id: ShapeId) throws -> T {
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
    
    
    /// Get list operations service uses. Slightly more complex than just asking for all the operation shapes in the fle. Instead to do
    /// this properly you need to ask the services for all its operations and resources and then combine the operations with all the
    /// operations from the resources
    static func getOperations(_ service: ServiceShape, model: Model) -> [ShapeId: OperationShape] {
        var operations: [ShapeId] = service.operations?.map { $0.target } ?? []

        func addResourceOperations(_ resource: ResourceShape) {
            resource.create.map { operations.append($0.target) }
            resource.put.map { operations.append($0.target) }
            resource.read.map { operations.append($0.target) }
            resource.update.map { operations.append($0.target) }
            resource.delete.map { operations.append($0.target) }
            resource.list.map { operations.append($0.target) }
            resource.operations?.forEach { operations.append($0.target) }
            resource.collectionOperations?.forEach { operations.append($0.target) }
            resource.resources?.forEach { resourceMember in
                guard let resource = model.shape(for: resourceMember.target) as? ResourceShape else { return }
                addResourceOperations(resource)
            }

        }
        
        if let resources = service.resources {
            resources.forEach { resourceMember in
                guard let resource = model.shape(for: resourceMember.target) as? ResourceShape else { return }
                addResourceOperations(resource)
            }
        }
        let operationsWithId = operations.compactMap { shapeId -> (ShapeId, OperationShape)? in
            if let operationShape = model.shape(for: shapeId) as? OperationShape {
                return (shapeId, operationShape)
            } else {
                return nil
            }
        }
        return .init(operationsWithId) { lhs, _ in lhs }
    }
    
    func getListEntryName(member: MemberShape, list: ListShape) -> String? {
        guard !member.hasTrait(type: XmlFlattenedTrait.self) else { return nil }
        guard let memberName = list.member.traits?.first(where: { $0 is AliasTrait}) as? AliasTrait else { return "member" }
        return memberName.alias
    }

    func getMapEntryNames(member: MemberShape, map: MapShape) -> (entry: String?, key: String, value: String) {
        let flattened = member.hasTrait(type: XmlFlattenedTrait.self)
        let keyTrait = map.key.traits?.first(where: { $0 is AliasTrait}) as? AliasTrait
        let valueTrait = map.value.traits?.first(where: { $0 is AliasTrait}) as? AliasTrait
        return (entry: flattened ? nil: "entry", key: keyTrait?.alias ?? "key", value: valueTrait?.alias ?? "value")
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
        switch serviceName {
        case "APIGateway":
            return "APIGatewayMiddleware()"
        case "Glacier":
            return "GlacierRequestMiddleware(apiVersion: \"\(service.version)\")"
        case "S3":
            return "S3RequestMiddleware()"
        case "S3Control":
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

    func encodingName(_ name: String) -> String {
        return "_\(name)Encoding"
    }

    /// return payload member of structure
    func getPayloadMember(from shape: CollectionShape) -> (key: String, value: MemberShape)? {
        guard let members = shape.members else { return nil }
        for member in members {
            if member.value.trait(type: HttpPayloadTrait.self) != nil {
                return member
            }
        }
        return nil
    }

    /// return if shape has a recursive reference (function only tests 2 levels)
    func doesShapeHaveRecursiveOwnReference(_ shape: CollectionShape, shapeId: ShapeId) -> Bool {
        guard let members = shape.members else { return false }
        let hasRecursiveOwnReference = members.values.contains(where: { member in
            // does shape have a member of same type as itself
            if member.target == shapeId {
                return true
            } else {
                guard let shape = model.shape(for: member.target) else { return false }
                switch shape {
                case let list as ListShape:
                    if list.member.target == shapeId {
                        return true
                    }
                case let set as SetShape:
                    if set.member.target == shapeId {
                        return true
                    }
                case let map as MapShape:
                    if map.value.target == shapeId {
                        return true
                    }
                case let structure as StructureShape:
                    return structure.members?.first{ $0.value.target == shapeId } != nil
                default:
                    break
                }
                return false
            }
        })

        return hasRecursiveOwnReference
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

        for operation in self.operations {
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

    /// Service endpoints from API and Endpoints structure
    func getServiceEndpoints() -> [(key: String, value: String)] {
        // create dictionary of endpoint name to Endpoint and partition from across all partitions
        struct EndpointInfo {
            let endpoint: Endpoints.Service.Endpoint
            let partition: String
        }
        let serviceEndpoints: [(key: String, value: EndpointInfo)] = self.endpoints.partitions.reduce([]) { value, partition in
            let endpoints = partition.services[self.serviceEndpointPrefix]?.endpoints
            return value + (endpoints?.map { (key: $0.key, value: EndpointInfo(endpoint: $0.value, partition: partition.partition)) } ?? [])
        }
        let partitionEndpoints = self.getPartitionEndpoints()
        let partitionEndpointSet = Set<String>(partitionEndpoints.map { $0.value.endpoint })
        return serviceEndpoints.compactMap {
            // if service endpoint isn't in the set of partition endpoints or a region name return nil
            if partitionEndpointSet.contains($0.key) == false, Region(rawValue: $0.key) == nil {
                return nil
            }
            // if endpoint has a hostname return that
            if let hostname = $0.value.endpoint.hostname {
                return (key: $0.key, value: hostname)
            } else if partitionEndpoints[$0.value.partition] != nil {
                // if there is a partition endpoint, then default this regions endpoint to ensure partition endpoint doesn't override it.
                // Only an issue for S3 at the moment.
                return (key: $0.key, value: "\(self.serviceEndpointPrefix).\($0.key).amazonaws.com")
            }
            return nil
        }
    }

    // return dictionary of partition endpoints keyed by endpoint name
    func getPartitionEndpoints() -> [String: (endpoint: String, region: Region)] {
        var partitionEndpoints: [String: (endpoint: String, region: Region)] = [:]
        endpoints.partitions.forEach {
            if let partitionEndpoint = $0.services[self.serviceEndpointPrefix]?.partitionEndpoint {
                guard let service = $0.services[self.serviceEndpointPrefix],
                      let endpoint = service.endpoints[partitionEndpoint],
                      let region = endpoint.credentialScope?.region else {
                    preconditionFailure("Found partition endpoint without a credential scope region")
                }
                partitionEndpoints[$0.partition] = (endpoint: partitionEndpoint, region: region)
            }
        }
        return partitionEndpoints
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
        let comment: [String.SubSequence]
    }

    struct EnumContext {
        let name: String
        let documentation: String?
        let values: [EnumMemberContext]
        let isExtensible: Bool
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
        let isEncodable: Bool
        let isDecodable: Bool
        let encoding: [EncodingPropertiesContext]
        let members: [MemberContext]
        let awsShapeMembers: [MemberEncodingContext]
        let codingKeys: [CodingKeysContext]
        let validation: [ValidationContext]
    }
}
