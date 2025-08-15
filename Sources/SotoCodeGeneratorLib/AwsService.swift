//===----------------------------------------------------------------------===//
//
// This source file is part of the Soto for AWS open source project
//
// Copyright (c) 2017-2023 the Soto project authors
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

struct AwsService {
    let model: Model
    let serviceName: String
    let serviceEndpointPrefix: String
    let serviceId: ShapeId
    let service: ServiceShape
    let serviceProtocolTrait: AwsServiceProtocol
    let endpoints: Endpoints
    var operations: [ShapeId: OperationShape]
    let outputHTMLComments: Bool
    let logger: Logger

    init(_ model: SotoSmithy.Model, endpoints: Endpoints, filter: [String]?, outputHTMLComments: Bool, logger: Logger) throws {
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

        self.endpoints = endpoints
        self.outputHTMLComments = outputHTMLComments
        self.logger = logger

        let operations = Self.getOperations(service.value, model: model)
        if let filter {
            self.operations = operations.filter { key, _ in
                filter.contains(key.shapeName.toSwiftVariableCase())
            }
        } else {
            self.operations = operations
        }

        self.markInputOutputShapes(model)
        // this is a breaking change (maybe for v8)
        // self.removeEmptyInputs(model)
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
        let serviceName =
            sdkId
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.prefix(1).capitalized + $0.dropFirst() }
            .joined()

        return serviceName
    }

    /// return service name used in endpoint. Uses filename of Smithy file
    static func getServiceEndpointPrefix(service: SotoSmithy.ServiceShape, id: ShapeId) throws -> String? {
        let awsService = try Self.getTrait(from: service, trait: AwsServiceTrait.self, id: id)
        return awsService.endpointPrefix ?? awsService.arnNamespace
    }

    /// Generate context for rendering service template
    func generateServiceContext() throws -> [String: Any] {
        var context: [String: Any] = [:]
        guard let serviceEntry = model.select(type: SotoSmithy.ServiceShape.self).first else { throw Error(reason: "No service object") }
        let serviceId = serviceEntry.key
        let service = serviceEntry.value
        let authSigV4 = service.trait(type: AwsAuthSigV4Trait.self)

        let operationContexts = try self.generateOperationContexts()

        context["name"] = self.serviceName
        context["description"] = self.processDocs(from: service)
        context["endpointPrefix"] = self.serviceEndpointPrefix
        if let authSigV4 = authSigV4, authSigV4.name != self.serviceEndpointPrefix {
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
                .map { ".\($0.partition.toSwiftRegionEnumCase()): (endpoint: \"\($0.endpoint)\", region: .\($0.region.toSwiftRegionEnumCase()))" }
        }
        context["variantEndpoints"] = self.getVariantEndpoints()
            .map { (variant: $0.key, endpoints: $0.value) }
            .sorted { $0.variant < $1.variant }
        context["operations"] = operationContexts.values.sorted { $0.funcName < $1.funcName }
        let paginators = try self.generatePaginatorContext(operationContexts)
        let waiters = try self.generateWaiterContexts(operationContexts)
        if paginators["paginators"] != nil {
            context["paginators"] = paginators
        }
        if waiters["waiters"] != nil {
            context["waiters"] = waiters
        }

        context["logger"] = self.getSymbol(for: "Logger", from: "Logging", model: self.model, namespace: serviceId.namespace ?? "")

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

        var errorMapContexts = errorShapes.compactMap { shape -> ErrorMapContext? in
            guard shape.value.hasTrait(type: SotoErrorShapeTrait.self) else { return nil }
            let queryError = isQueryProtocol ? shape.value.trait(type: AwsProtocolsAwsQueryErrorTrait.self) : nil
            let errorCode: String = queryError?.code ?? shape.key.shapeName
            return ErrorMapContext(code: errorCode, error: shape.key.shapeName)
        }
        errorMapContexts.sort { $0.code < $1.code }
        if errorMapContexts.count > 0 {
            context["errorMap"] = errorMapContexts
        }
        return context
    }

    /// Generate map of operation
    func generateOperationContexts() throws -> [ShapeId: OperationContext] {
        var operationContexts: [ShapeId: OperationContext] = [:]
        let operations = self.operations
        for operation in operations {
            let operationContext = try generateOperationContext(
                operation.value,
                operationName: operation.key,
                streaming: false
            )
            operationContexts[operation.key] = operationContext
        }
        return operationContexts
    }

    /// Generate context for rendering a single operation. Used by both `generateServiceContext` and `generatePaginatorContext`
    func generateOperationContext(
        _ operation: OperationShape,
        operationName: ShapeId,
        streaming: Bool
    ) throws -> OperationContext {
        let httpTrait = operation.trait(type: HttpTrait.self)
        let deprecatedTrait = operation.trait(type: DeprecatedTrait.self)
        let endpointTrait = operation.trait(type: EndpointTrait.self)
        let requireEndpointDiscovery = operation.trait(type: AwsClientDiscoveredEndpointTrait.self)?.required
        var inputShapeTarget = operation.input?.target
        var outputShapeTarget = operation.output?.target
        // Check if target shape is a unit shape and thus Void. I could go and find the shape and check if it is a unit
        // shape or I could just check its name. Spec is pretty clear there is only one unit type
        // https://awslabs.github.io/smithy/1.0/spec/core/model.html#unit-type
        if inputShapeTarget == "smithy.api#Unit" {
            inputShapeTarget = nil
        }
        if outputShapeTarget == "smithy.api#Unit" {
            outputShapeTarget = nil
        }
        // get member contexts from shape
        var initParamContext: [OperationInitParamContext] = []
        if let inputShapeTarget {
            initParamContext = self.generateInitParameterContexts(inputShapeTarget)
        }
        return OperationContext(
            comment: self.processDocs(from: operation),
            funcName: operationName.shapeName.toSwiftVariableCase(),
            inputShape: inputShapeTarget?.shapeName,
            outputShape: outputShapeTarget?.shapeName,
            name: operationName.shapeName,
            path: httpTrait?.uri ?? "/",
            httpMethod: httpTrait?.method ?? "POST",
            hostPrefix: endpointTrait?.hostPrefix,
            deprecated: deprecatedTrait?.message,
            streaming: streaming ? "ByteBuffer" : nil,
            documentationUrl: nil,  // added to comment
            endpointRequired: requireEndpointDiscovery.map { OperationContext.DiscoverableEndpoint(required: $0) },
            initParameters: initParamContext,
            taskLocals: generateTaskLocals(operation: operation)
        )
    }

    func generateInitParameterContexts(_ inputShapeId: ShapeId) -> [OperationInitParamContext] {
        guard let shape = self.model.shape(for: inputShapeId) as? StructureShape else { return [] }
        guard let members = shape.members else { return [] }
        let sortedMembers = members.map { $0 }.sorted { $0.key.lowercased() < $1.key.lowercased() }
        var contexts: [MemberContext] = []
        for member in sortedMembers {
            guard let targetShape = self.model.shape(for: member.value.target) else { continue }
            // member context
            let memberContext = self.generateMemberContext(
                member.value,
                targetShape: targetShape,
                name: member.key,
                shapeName: inputShapeId.shapeName,
                typeIsUnion: false,
                isOutputShape: false
            )
            contexts.append(memberContext)
        }
        return contexts.compactMap {
            if !$0.deprecated {
                OperationInitParamContext(
                    variable: $0.variable,
                    parameter: $0.parameter,
                    type: $0.type,
                    default: $0.default,
                    comment: $0.comment
                )
            } else {
                nil
            }
        }
    }

    func generateTaskLocals(
        operation: OperationShape
    ) -> TaskLocalParameters? {
        guard let staticParamsTrait = operation.trait(type: StaticContextParamsTrait.self) else { return nil }
        let name: String
        let possibleParameters: [String]
        switch self.serviceEndpointPrefix {
        case "s3":
            name = "S3Middleware.$executionContext"
            possibleParameters = ["UseS3ExpressControlEndpoint"]
        default:
            return nil
        }
        let parameters = staticParamsTrait.value
            .filter { possibleParameters.contains($0.key) }
            .compactMap { param in
                param.value.dictionary?["value"].map { TaskLocalParameters.Parameter(key: param.key.toSwiftLabelCase(), value: $0) }
            }
        return !parameters.isEmpty ? .init(taskLocalName: name, taskLocalParams: parameters) : nil
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
        var operations: [ShapeId] = service.operations?.map(\.target) ?? []

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
        guard let memberName = list.member.trait(named: serviceProtocolTrait.nameTrait.staticName) as? ProtocolAliasTrait else { return "member" }
        return memberName.alias
    }

    func getMapEntryNames(member: MemberShape, map: MapShape) -> (entry: String?, key: String, value: String) {
        let flattened = member.hasTrait(type: XmlFlattenedTrait.self)
        let keyTrait = map.key.trait(named: self.serviceProtocolTrait.nameTrait.staticName) as? ProtocolAliasTrait
        let valueTrait = map.value.trait(named: self.serviceProtocolTrait.nameTrait.staticName) as? ProtocolAliasTrait
        return (entry: flattened ? nil : "entry", key: keyTrait?.alias ?? "key", value: valueTrait?.alias ?? "value")
    }

    /// process documenation string
    func processDocs(from shape: Shape) -> [Substring] {
        var docs: [Substring]

        let documentation = shape.trait(type: DocumentationTrait.self)?.value
        if self.outputHTMLComments {
            docs = documentation?.split(separator: "\n") ?? []
        } else {
            docs =
                documentation?
                .tagStriped()
                .replacingOccurrences(of: "\n +", with: " ", options: .regularExpression, range: nil)
                .split(separator: "\n")
                .compactMap { $0.isEmpty ? nil : $0 }
                .map { $0.dropLast(while: { $0.isWhitespace }) } ?? []
        }

        if let externalDocumentation = shape.trait(type: ExternalDocumentationTrait.self)?.value {
            for (key, value) in externalDocumentation {
                docs.append("\(key): \(value)")
            }
        }
        return docs
    }

    /// process documenation string
    func processMemberDocs(from shape: MemberShape) -> [Substring] {
        guard var documentation = shape.trait(type: DocumentationTrait.self)?.value else { return [] }
        if let recommendation = shape.trait(type: RecommendedTrait.self)?.reason {
            documentation += "\n\(recommendation)"
        }
        return
            documentation
            .tagStriped()
            .replacingOccurrences(of: "\n +", with: " ", options: .regularExpression, range: nil)
            .split(separator: "\n")
            .compactMap { $0.isEmpty ? nil : $0 }
            .map { $0.dropLast(while: { $0.isWhitespace }) }
    }

    /// process documentation string
    func processDocs(_ documentation: String?) -> [String.SubSequence] {
        documentation?
            .tagStriped()
            .replacingOccurrences(of: "\n +", with: " ", options: .regularExpression, range: nil)
            .split(separator: "\n")
            .compactMap { $0.isEmpty ? nil : $0 } ?? []
    }

    /// return middleware name given a service name
    func getMiddleware(for service: ServiceShape) -> String? {
        switch self.serviceName {
        case "APIGateway":
            return "AWSEditHeadersMiddleware(.add(name: \"accept\", value: \"application/json\"))"
        case "Glacier":
            return """
                AWSMiddlewareStack {
                                AWSEditHeadersMiddleware(.add(name: \"x-amz-glacier-version\", value: \"\(service.version ?? "2012-06-01")\"))
                                TreeHashMiddleware(header: \"x-amz-sha256-tree-hash\")
                            }
                """
        case "S3":
            return "S3Middleware()"
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
        "_\(name)Encoding"
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

    /// return if shape has a recursive reference (checks 4 layers of references)
    func doesShapeHaveRecursiveOwnReference(_ shape: CollectionShape, shapeId: ShapeId) -> Bool {
        func hasRecursiveOwnReference(_ shape: CollectionShape, count: Int) -> Bool {
            if count > 4 { return false }
            guard let members = shape.members else { return false }
            return members.values.contains(where: { member in
                // does shape have a member of same type as itself
                if member.target == shapeId {
                    return true
                } else {
                    guard let shape = model.shape(for: member.target) else { return false }
                    switch shape {
                    case let collection as CollectionShape:
                        return hasRecursiveOwnReference(collection, count: count + 1)
                    default:
                        break
                    }
                    return false
                }
            })
        }
        return hasRecursiveOwnReference(shape, count: 0)
    }

    /// mark up model with Soto traits for input and output shapes
    func markInputOutputShapes(_ model: Model) {
        func addTrait<T: StaticTrait>(to shapeId: ShapeId, trait: T) {
            guard let shape = model.shape(for: shapeId) else { return }
            // don't mark shapes that are marked as stubs
            guard shape.trait(type: SotoStubTrait.self) == nil else { return }
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
            if let errors = operation.value.errors {
                for error in errors {
                    if let shape = model.shape(for: error.target) {
                        // Only add error trait to errors with more properties than just a message
                        switch shape {
                        case let shape as StructureShape:
                            guard let members = shape.members, members.count > 0 else { continue }
                            if members.count == 1 && members.keys.first?.lowercased() == "message" { continue }
                        case is UnionShape:
                            break
                        default:
                            continue
                        }
                        shape.add(trait: SotoErrorShapeTrait())
                    }
                    addTrait(to: error.target, trait: SotoOutputShapeTrait())
                }
            }
        }
    }

    func removeEmptyInputs(_ model: Model) {
        for operation in self.operations {
            if let input = operation.value.input {
                if let shape = model.shape(for: input.target) {
                    if let structureShape = shape as? StructureShape {
                        if let members = structureShape.members {
                            if members.count == 0 {
                                operation.value.input = nil
                            }
                        } else {
                            operation.value.input = nil
                        }
                    }
                }
            }
        }
    }

    /// The JSON decoder requires an array to exist, even if it is empty so we have to make
    /// all arrays in output shapes optional
    func removeRequiredTraitFromOutputCollections(_ model: Model) {
        guard
            self.serviceProtocolTrait is AwsProtocolsAwsJson1_0Trait || self.serviceProtocolTrait is AwsProtocolsAwsJson1_1Trait
                || self.serviceProtocolTrait is AwsProtocolsRestJson1Trait
        else { return }

        for shape in model.shapes {
            guard shape.value.hasTrait(type: SotoOutputShapeTrait.self) else { continue }
            guard let structure = shape.value as? StructureShape else { continue }
            guard let members = structure.members else { continue }
            for member in members.values {
                let shape = model.shape(for: member.target)
                if shape is ListShape || shape is SetShape || shape is MapShape {
                    member.remove(trait: RequiredTrait.self)
                }
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
        if let member = structure.members?[String(split[0])] {
            let required =
                member.hasTrait(type: RequiredTrait.self)
                || (member.hasTrait(type: HttpPayloadTrait.self) && structure.hasTrait(type: SotoOutputShapeTrait.self))
            if !required, split.count > 1 {
                split[0] += "?"
            }
        }
        return split.map { String($0).toSwiftVariableCase() }.joined(separator: ".")
    }

    /// Service endpoints from API and Endpoints structure
    func getServiceEndpoints() -> [(key: String, value: String)] {
        // create dictionary of endpoint name to Endpoint and partition from across all partitions
        struct EndpointInfo {
            let endpoint: Endpoints.Endpoint
            let partition: String
        }
        let serviceEndpoints = self.endpoints.partitions.flatMap { partition -> [(key: String, value: EndpointInfo)] in
            guard let endpoints = partition.services[self.serviceEndpointPrefix]?.endpoints else { return [] }
            let endpointInfo = endpoints.compactMap { endpoint -> (key: String, value: EndpointInfo)? in
                if endpoint.value.deprecated == true {
                    return nil
                }
                return (key: endpoint.key, value: EndpointInfo(endpoint: endpoint.value, partition: partition.partition))
            }
            return endpointInfo
        }
        let partitionEndpoints = self.getPartitionEndpoints()
        return serviceEndpoints.compactMap {
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
    func getPartitionEndpoints() -> [String: (endpoint: String, region: String)] {
        var partitionEndpoints: [String: (endpoint: String, region: String)] = [:]
        self.endpoints.partitions.forEach {
            guard let service = $0.services[self.serviceEndpointPrefix] else { return }
            guard let partitionEndpoint = service.partitionEndpoint else { return }
            guard let endpoint = service.endpoints[partitionEndpoint] else {
                self.logger.error(
                    "Partition endpoint \(partitionEndpoint) for service \(self.serviceEndpointPrefix) in \($0.partitionName) does not exist"
                )
                return
            }
            guard let region = endpoint.credentialScope?.region else {
                // services with SigV4 authentication require an endpoint
                if self.service.trait(type: AwsAuthSigV4Trait.self) != nil {
                    self.logger.error(
                        "Partition endpoint \(partitionEndpoint) for service \(self.serviceEndpointPrefix) in \($0.partitionName) has no credential scope region"
                    )
                }
                return
            }
            partitionEndpoints[$0.partition] = (endpoint: partitionEndpoint, region: region)
        }
        return partitionEndpoints
    }

    func getVariantEndpoints() -> [String: VariantContext] {
        var variantEndpoints: [String: VariantContext] = [:]
        self.endpoints.partitions.forEach { partition in
            guard let service = partition.services[self.serviceEndpointPrefix] else { return }
            return service.endpoints.forEach { endpoint in
                guard endpoint.value.deprecated != true else { return }
                var endpointValue = endpoint.value
                // apply service defaults to endpoint info
                if let defaults = service.defaults {
                    endpointValue = endpointValue.applyingDefaults(defaults)
                }
                endpointValue = endpointValue.applyingPartitionDefaults(partition.defaults)
                guard let variants = endpointValue.variants else { return }
                for variant in variants {
                    let variantString = variant.tags
                        .map { ".\($0)" }
                        .sorted()
                        .joined(separator: ", ")
                    // get dnsSuffix for this variant
                    guard
                        let dnsSuffix = getDefaultValue(
                            partition: partition,
                            service: service,
                            getValue: { defaults in
                                defaults.variants?.first(where: { $0.tags == variant.tags })?.dnsSuffix
                            }
                        )
                    else {
                        continue
                    }
                    if variantEndpoints[variantString] == nil {
                        variantEndpoints[variantString] = .init()
                    }
                    if let hostname = variant.hostname {
                        // get hostname and replace any variables (wrapped in {}) in hostname
                        let finalHostname =
                            hostname
                            .replacingOccurrences(of: "{region}", with: endpoint.key)
                            .replacingOccurrences(of: "{dnsSuffix}", with: dnsSuffix)
                            .replacingOccurrences(of: "{service}", with: self.serviceEndpointPrefix)
                        // add variant endpoint
                        variantEndpoints[variantString]!.endpoints.append((region: endpoint.key, hostname: finalHostname))
                    }
                }
            }
        }
        // return variants with endpoints sorted by region name
        return variantEndpoints.mapValues {
            .init(defaultEndpoint: $0.defaultEndpoint, endpoints: $0.endpoints.sorted { $0.region < $1.region })
        }
    }

    func getDefaultValue<Value>(
        partition: Endpoints.Partition,
        service: Endpoints.Service,
        getValue: (Endpoints.Defaults) -> Value?
    ) -> Value? {
        if let serviceDefaults = service.defaults, let value = getValue(serviceDefaults) {
            return value
        } else if let value = getValue(partition.defaults) {
            return value
        }
        return nil
    }

    /// get protocol needed for shape
    func getShapeProtocol(_ shape: Shape, hasPayload: Bool) -> String? {
        let usedInInput = shape.hasTrait(type: SotoInputShapeTrait.self)
        let usedInOutput = shape.hasTrait(type: SotoOutputShapeTrait.self)
        let isError = shape.hasTrait(type: SotoErrorShapeTrait.self)
        var shapeProtocol: String
        if usedInInput {
            shapeProtocol = "AWSEncodableShape"
            if usedInOutput {
                shapeProtocol += " & AWSDecodableShape"
            }
        } else if isError {
            shapeProtocol = "AWSErrorShape"
        } else if usedInOutput {
            shapeProtocol = "AWSDecodableShape"
        } else {
            return nil
        }
        return shapeProtocol
    }

    func isMemberInBody(_ member: MemberShape, isOutputShape: Bool) -> Bool {
        !(member.hasTrait(type: HttpHeaderTrait.self) || member.hasTrait(type: HttpPrefixHeadersTrait.self)
            || (member.hasTrait(type: HttpQueryTrait.self) && !isOutputShape) || member.hasTrait(type: HttpQueryParamsTrait.self)
            || member.hasTrait(type: HttpLabelTrait.self) || member.hasTrait(type: HttpResponseCodeTrait.self))
    }
}

protocol EncodingPropertiesContext {}

extension AwsService {
    struct Error: Swift.Error {
        let reason: String
    }

    struct TaskLocalParameters {
        struct Parameter {
            let key: String
            let value: Any
        }
        let taskLocalName: String
        let taskLocalParams: [Parameter]
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
        var initParameters: [OperationInitParamContext]
        let taskLocals: TaskLocalParameters?
    }

    struct OperationInitParamContext {
        let variable: String
        let parameter: String
        let type: String
        let `default`: String?
        let comment: [String.SubSequence]
    }

    struct ShapesContext {
        enum ShapeType {
            case `enum`(EnumContext)
            case `struct`(StructureContext)
            case enumWithValues(StructureContext)
        }

        let name: String
        let shapes: [ShapeType]
        let errors: [String: Any]?
        var scope: String
        let extraCode: String?
    }

    struct PaginatorContext {
        let operation: OperationContext
        let inputKey: String?
        let outputKey: String
        let moreResultsKey: String?
    }

    struct PaginatorShapeContext {
        let inputShape: String
        let initParams: [String]
        let paginatorProtocol: String
        let tokenType: String
    }

    struct ErrorContext {
        let `enum`: String
        let string: String
        let comment: [String.SubSequence]
    }

    struct ErrorMapContext {
        let code: String
        let error: String
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
        let rawValue: String
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

    struct MemberCodableContext {
        init(
            inHeader: String? = nil,
            inQuery: String? = nil,
            inURI: String? = nil,
            inHostPrefix: String? = nil,
            areQueryParams: Bool = false,
            isUnit: Bool = false,
            isPayload: Bool = false,
            isCodable: Bool = false,
            isStatusCode: Bool = false,
            codableType: String
        ) {
            self.inHeader = inHeader
            self.inQuery = inQuery
            self.inURI = inURI
            self.inHostPrefix = inHostPrefix
            self.areQueryParams = areQueryParams
            self.isUnit = isUnit
            self.isPayload = isPayload
            self.isCodable = isCodable
            self.isStatusCode = isStatusCode
            self.codableType = codableType
        }

        var inHeader: String?
        var inQuery: String?
        var inURI: String?
        var inHostPrefix: String?
        var areQueryParams: Bool
        var isUnit: Bool
        var isPayload: Bool
        var isCodable: Bool
        var isStatusCode: Bool
        var codableType: String
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
        var memberCoding: MemberCodableContext
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

    class ValidationContext: MustacheTransformable {
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
        let rawValue: String
        var duplicate: Bool
    }

    struct VariantContext {
        var defaultEndpoint: String?
        var endpoints: [(region: String, hostname: String)] = []
    }

    struct ShapeCodingContext {
        let requiresResponse: Bool
        let requiresEvent: Bool
        let requiresDecodeInit: Bool
        let requiresEncode: Bool
        let singleValueContainer: Bool
    }

    struct StructureContext {
        let object: String
        let name: String
        let shapeProtocol: String
        var options: String?
        let namespace: String?
        let xmlRootNodeName: String?
        let shapeCoding: ShapeCodingContext?
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
        case success(Int)  // Success requires a dummy associated value, so a mustache context is created for the `MatcherContext`
    }
}
