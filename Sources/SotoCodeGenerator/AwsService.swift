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

struct AwsService {
    var model: Model
    var serviceName: String
    var serviceEndpointPrefix: String
    var serviceId: ShapeId
    var service: ServiceShape
    var serviceProtocolTrait: AwsServiceProtocol
    var endpoints: Endpoints
    var operations: [ShapeId: OperationShape]
    var outputHTMLComments: Bool

    init(_ model: SotoSmithy.Model, endpoints: Endpoints, outputHTMLComments: Bool) throws {
        guard let service = model.select(type: SotoSmithy.ServiceShape.self).first else { throw Error(reason: "No service object") }

        self.model = model
        self.serviceId = service.key
        self.service = service.value
        var serviceName = try Self.getServiceName(service.value, id: service.key)
        try model.patch(serviceName: serviceName)
        serviceName = try Self.getServiceName(service.value, id: service.key)
        self.serviceName = serviceName
        self.serviceEndpointPrefix = try Self.getServiceEndpointPrefix(service: service.value, id: service.key) ?? serviceName.lowercased()
        self.serviceProtocolTrait = try Self.getServiceProtocol(service.value)

        self.operations = Self.getOperations(service.value, model: model)

        self.endpoints = endpoints
        self.outputHTMLComments = outputHTMLComments
    }

    /// Return service name from API
    static func getServiceName(_ service: SotoSmithy.ServiceShape, id: ShapeId) throws -> String {
        guard let awsService = service.trait(type: AwsServiceTrait.self) else {
            throw Error(reason: "\(id) does not have a \(AwsServiceTrait.staticName) trait")
        }

        // https://awslabs.github.io/smithy/1.0/spec/aws/aws-core.html#choosing-an-sdk-service-id

        var sdkId = awsService.sdkId

        // Strip out prefix names not reflected in service client symbol names.
        let stripServiceNamePrefixes: [String] = ["Amazon", "AWS"]
        for prefix in stripServiceNamePrefixes {
            sdkId.deletePrefix(prefix)
        }

        // separate by non-alphanumeric character, then capitalize the first letter of each component
        // and join back together
        let serviceName = sdkId
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.prefix(1).capitalized + $0.dropFirst() }
            .joined()

        return serviceName
    }

    /// return service name used in endpoint. Uses filename of Smithy file
    static func getServiceEndpointPrefix(service: SotoSmithy.ServiceShape, id: ShapeId) throws -> String? {
        let awsService = try Self.getTrait(from: service, trait: AwsServiceTrait.self, id: id)
        return awsService.endpointPrefix
    }

    /// Generate context for rendering service template
    func generateServiceContext() throws -> [String: Any] {
        var context: [String: Any] = [:]
        guard let serviceEntry = model.select(type: SotoSmithy.ServiceShape.self).first else { throw Error(reason: "No service object") }
        let serviceId = serviceEntry.key
        let service = serviceEntry.value
        let authSigV4 = try Self.getTrait(from: service, trait: AwsAuthSigV4Trait.self, id: serviceId)
        let operations = try generateOperationContexts()

        context["name"] = self.serviceName
        context["description"] = self.processDocs(from: service)
        context["endpointPrefix"] = self.serviceEndpointPrefix
        if authSigV4.name != self.serviceEndpointPrefix {
            context["signingName"] = authSigV4.name
        }
        context["protocol"] = self.serviceProtocolTrait.output
        context["apiVersion"] = service.version
        if self.serviceProtocolTrait is AwsProtocolsAwsJson1_0Trait || self.serviceProtocolTrait is AwsProtocolsAwsJson1_1Trait {
            context["amzTarget"] = serviceId.shapeName
        }
        if !self.model.select(with: TraitSelector<ErrorTrait>()).isEmpty {
            context["errorTypes"] = self.serviceName + "ErrorType"
        }
        context["xmlNamespace"] = service.trait(type: XmlNamespaceTrait.self)?.uri
        context["middlewareClass"] = self.getMiddleware(for: service)
        context["endpointDiscovery"] = service.trait(type: AwsClientEndpointDiscoveryTrait.self)?.operation.shapeName.toSwiftVariableCase()

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
        context["logger"] = self.getSymbol(for: "Logger", from: "Logging", model: self.model, namespace: serviceId.namespace ?? "")
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
            let paginatedTruncatedTrait = operationShape.trait(type: SotoPaginationTruncatedTrait.self)
            let inputMemberShapeName = inputMember.output(self.model, withServiceName: self.serviceName)

            // construct array of input shape parameters to use in `usingPaginationToken` function
            var initParams: [String: String] = [:]
            for member in inputShape.members ?? [:] {
                // don't include deprecated members
                guard !member.value.hasTrait(type: DeprecatedTrait.self) else { continue }
                initParams[member.key.toSwiftLabelCase()] = "self.\(member.key.toSwiftLabelCase())"
            }
            initParams[inputToken.toSwiftLabelCase()] = "token"
            let initParamsArray = initParams.map { "\($0.key): \($0.value)" }.sorted { $0.lowercased() < $1.lowercased() }

            var inputKeyToken: String? = inputToken
            guard let inputKeyShape = model.shape(for: inputMember.target) else { continue }
            // if input key shape is not equatable then don't output input key
            if !(inputKeyShape is SotoEquatableShape) {
                inputKeyToken = nil
            }
            // if we have a `isTruncated` flag then don't output input
            if paginatedTruncatedTrait != nil {
                inputKeyToken = nil
            }

            paginatorContexts.append(
                PaginatorContext(
                    operation: try self.generateOperationContext(operationShape, operationName: operation.key, streaming: false),
                    inputKey: inputKeyToken.map { self.toKeyPath(token: $0, structure: inputShape) },
                    outputKey: self.toKeyPath(token: outputToken, structure: outputShape),
                    moreResultsKey: paginatedTruncatedTrait.map { self.toKeyPath(token: $0.isTruncated, structure: outputShape) },
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
        context["logger"] = self.getSymbol(for: "Logger", from: "Logging", model: self.model, namespace: namespace ?? "")
        return context
    }

    /// Generate the context information for outputting the error enums
    func generateErrorContext() throws -> [String: Any] {
        let errorShapes = try model.select(from: "structure [trait|error]")
        guard errorShapes.count > 0 else { return [:] }
        let isQueryProtocol = self.service.hasTrait(type: AwsProtocolsAwsQueryTrait.self)

        var context: [String: Any] = [:]
        context["name"] = self.serviceName
        context["errorName"] = self.serviceName + "ErrorType"

        var errorContexts: [ErrorContext] = []
        for error in errorShapes {
            let queryError = isQueryProtocol ? error.value.trait(type: AwsProtocolsAwsQueryErrorTrait.self) : nil
            let name: String = queryError?.code ?? error.key.shapeName
            let errorContext = ErrorContext(
                enum: error.key.shapeName.toSwiftVariableCase(),
                string: name,
                comment: self.processDocs(from: error.value)
            )
            errorContexts.append(errorContext)
        }
        errorContexts.sort { $0.enum < $1.enum }
        if errorContexts.count > 0 {
            context["errors"] = errorContexts
        }
        return context
    }

    /// Generate list of operation and streaming operation contexts
    func generateOperationContexts() throws -> (operations: [OperationContext], streamingOperations: [OperationContext]) {
        var operationContexts: [OperationContext] = []
        var streamingOperationContexts: [OperationContext] = []
        let operations = self.operations
        for operation in operations {
            let operationContext = try generateOperationContext(operation.value, operationName: operation.key, streaming: false)
            operationContexts.append(operationContext)

            if let output = operation.value.output,
               let outputShape = model.shape(for: output.target) as? StructureShape,
               let payloadMember = getPayloadMember(from: outputShape),
               let payloadShape = model.shape(for: payloadMember.value.target),
               payloadShape.trait(type: StreamingTrait.self) != nil,
               payloadShape is BlobShape
            {
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
    func generateOperationContext(_ operation: OperationShape, operationName: ShapeId, streaming: Bool) throws -> OperationContext {
        let httpTrait = operation.trait(type: HttpTrait.self)
        let deprecatedTrait = operation.trait(type: DeprecatedTrait.self)
        let endpointTrait = operation.trait(type: EndpointTrait.self)
        let requireEndpointDiscovery = operation.trait(type: AwsClientDiscoveredEndpointTrait.self)?.required

        return OperationContext(
            comment: self.processDocs(from: operation),
            funcName: operationName.shapeName.toSwiftVariableCase(),
            inputShape: operation.input?.target.shapeName,
            outputShape: operation.output?.target.shapeName,
            name: operationName.shapeName,
            path: httpTrait?.uri ?? "/",
            httpMethod: httpTrait?.method ?? "POST",
            hostPrefix: endpointTrait?.hostPrefix,
            deprecated: deprecatedTrait?.message,
            streaming: streaming ? "ByteBuffer" : nil,
            documentationUrl: nil, // added to comment
            endpointRequired: requireEndpointDiscovery.map { OperationContext.DiscoverableEndpoint(required: $0) }
        )
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
        guard let memberName = list.member.traits?.first(where: { $0 is AliasTrait }) as? AliasTrait else { return "member" }
        return memberName.alias
    }

    func getMapEntryNames(member: MemberShape, map: MapShape) -> (entry: String?, key: String, value: String) {
        let flattened = member.hasTrait(type: XmlFlattenedTrait.self)
        let keyTrait = map.key.traits?.first(where: { $0 is AliasTrait }) as? AliasTrait
        let valueTrait = map.value.traits?.first(where: { $0 is AliasTrait }) as? AliasTrait
        return (entry: flattened ? nil : "entry", key: keyTrait?.alias ?? "key", value: valueTrait?.alias ?? "value")
    }

    /// process documenation string
    func processDocs(from shape: Shape) -> [String.SubSequence] {
        var docs: [String.SubSequence]

        let documentation = shape.trait(type: DocumentationTrait.self)?.value
        if self.outputHTMLComments {
            docs = documentation?.split(separator: "\n") ?? []
        } else {
            docs = documentation?
                .tagStriped()
                .replacingOccurrences(of: "\n +", with: " ", options: .regularExpression, range: nil)
                .split(separator: "\n")
                .compactMap { $0.isEmpty ? nil : $0 } ?? []
        }

        if let externalDocumentation = shape.trait(type: ExternalDocumentationTrait.self)?.value {
            for (key, value) in externalDocumentation {
                docs.append("\(key): \(value)")
            }
        }
        return docs
    }

    /// process documenation string
    func processMemberDocs(from shape: MemberShape) -> [String.SubSequence] {
        let documentation = shape.trait(type: DocumentationTrait.self)?.value
        return documentation?
            .tagStriped()
            .replacingOccurrences(of: "\n +", with: " ", options: .regularExpression, range: nil)
            .split(separator: "\n")
            .compactMap { $0.isEmpty ? nil : $0 } ?? []
    }

    /// process documentation string
    func processDocs(_ documentation: String?) -> [String.SubSequence] {
        return documentation?
            .tagStriped()
            .replacingOccurrences(of: "\n +", with: " ", options: .regularExpression, range: nil)
            .split(separator: "\n")
            .compactMap { $0.isEmpty ? nil : $0 } ?? []
    }

    /// return middleware name given a service name
    func getMiddleware(for service: ServiceShape) -> String? {
        switch self.serviceName {
        case "APIGateway":
            return "APIGatewayMiddleware()"
        case "Glacier":
            return "GlacierRequestMiddleware(apiVersion: \"\(service.version)\")"
        case "S3":
            return "S3RequestMiddleware()"
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
                    return structure.members?.first { $0.value.target == shapeId } != nil
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
                if let shape = model.shape(for: input.target) {
                    shape.add(trait: SotoRequestShapeTrait(operationShape: operation.value))
                }
                addTrait(to: input.target, trait: SotoInputShapeTrait())
            }
            if let output = operation.value.output {
                if let shape = model.shape(for: output.target) {
                    shape.add(trait: SotoResponseShapeTrait(operationShape: operation.value))
                }
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

        if let member = structure.members?[String(split[0])],
           !member.hasTrait(type: RequiredTrait.self),
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
        self.endpoints.partitions.forEach {
            if let partitionEndpoint = $0.services[self.serviceEndpointPrefix]?.partitionEndpoint {
                guard let service = $0.services[self.serviceEndpointPrefix],
                      let endpoint = service.endpoints[partitionEndpoint],
                      let region = endpoint.credentialScope?.region
                else {
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

    func isMemberInBody(_ member: MemberShape) -> Bool {
        return !(member.hasTrait(type: HttpHeaderTrait.self) ||
            member.hasTrait(type: HttpPrefixHeadersTrait.self) ||
            member.hasTrait(type: HttpQueryTrait.self) ||
            member.hasTrait(type: HttpLabelTrait.self) ||
            member.hasTrait(type: HttpResponseCodeTrait.self))
    }
}

protocol EncodingPropertiesContext {}

extension AwsService {
    struct Error: Swift.Error {
        let reason: String
    }

    struct OperationContext {
        struct DiscoverableEndpoint {
            let required: Bool
        }

        let comment: [String.SubSequence]
        let funcName: String
        let inputShape: String?
        let outputShape: String?
        let name: String
        let path: String
        let httpMethod: String
        let hostPrefix: String?
        let deprecated: String?
        let streaming: String?
        let documentationUrl: String?
        let endpointRequired: DiscoverableEndpoint?
    }

    struct PaginatorContext {
        let operation: OperationContext
        let inputKey: String?
        let outputKey: String
        let moreResultsKey: String?
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
        let documentation: [String.SubSequence]
        let values: [EnumMemberContext]
        let isExtensible: Bool
    }

    struct EnumMemberContext {
        let `case`: String
        let documentation: [String.SubSequence]
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
        let deprecated: Bool
        var duplicate: Bool
    }

    struct InitParamContext {
        let parameter: String
        let type: String
        let `default`: String?
    }

    struct MemberEncodingContext {
        let name: String
        let location: String?
    }

    class ValidationContext: HBMustacheTransformable {
        let name: String
        let shape: Bool
        let required: Bool
        let reqs: [String: Any]
        let member: ValidationContext?
        let keyValidation: ValidationContext?
        let valueValidation: ValidationContext?

        init(
            name: String,
            shape: Bool = false,
            required: Bool = true,
            reqs: [String: Any] = [:],
            member: ValidationContext? = nil,
            keyValidation: ValidationContext? = nil,
            valueValidation: ValidationContext? = nil
        ) {
            self.name = name
            self.shape = shape
            self.required = required
            self.reqs = reqs
            self.member = member
            self.keyValidation = keyValidation
            self.valueValidation = valueValidation
        }

        func transform(_ name: String) -> Any? {
            switch name {
            case "withDictionaryContexts":
                if self.keyValidation != nil || self.valueValidation != nil {
                    return self
                }
            default:
                break
            }
            return nil
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
        var options: String?
        let namespace: String?
        let isEncodable: Bool
        let isDecodable: Bool
        let encoding: [EncodingPropertiesContext]
        let members: [MemberContext]
        let initParameters: [InitParamContext]
        let awsShapeMembers: [MemberEncodingContext]
        let codingKeys: [CodingKeysContext]
        let validation: [ValidationContext]
        let requiresDefaultValidation: Bool
        let deprecatedMembers: [String]
    }

    struct WaiterContext {
        let waiterName: String
        let operation: OperationContext
        let inputKey: String?
        let acceptors: [AcceptorContext]
        let minDelayTime: Int?
        let maxDelayTime: Int?
        let deprecated: Bool
        let comment: [String.SubSequence]
    }

    struct AcceptorContext {
        let state: String
        let matcher: MatcherContext
    }

    enum MatcherContext {
        case jmesPath(path: String, expected: String)
        case jmesAnyPath(path: String, expected: String)
        case jmesAllPath(path: String, expected: String)
        case error(String)
        case errorStatus(Int)
        case success(Int) // Success requires a dummy associated value, so a mustache context is created for the `MatcherContext`
    }
}
