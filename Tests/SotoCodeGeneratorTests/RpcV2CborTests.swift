//===----------------------------------------------------------------------===//
//
// This source file is part of the Soto for AWS open source project
//
// Copyright (c) 2025 the Soto project authors
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
import Testing

@testable import SotoCodeGeneratorLib

@Suite("rpcv2Cbor")
struct RpcV2CborTests {
    /// Register the traits the generator needs. Registration is global state, so do it once.
    private static let registered: Void = {
        Smithy.registerShapesAndTraits()
        Smithy.registerAWSTraits()
        Smithy.registerTraitTypes(
            SotoInputShapeTrait.self,
            SotoOutputShapeTrait.self,
            SmithyProtocolsRpcv2CborTrait.self
        )
    }()

    /// Smithy JSON AST for a small service. `protocolTraits` are the protocol traits placed on the service.
    private static func modelJSON(protocolTraits: [String]) -> String {
        let serviceTraits =
            (protocolTraits.map { "\"\($0)\": {}" } + [
                #""aws.api#service": {"sdkId": "Cbor Test", "endpointPrefix": "cbortest"}"#,
                #""aws.auth#sigv4": {"name": "cbortest"}"#,
            ]).joined(separator: ",\n")
        return """
            {
              "smithy": "2.0",
              "shapes": {
                "example.cbor#CborTest": {
                  "type": "service",
                  "version": "2020-01-01",
                  "operations": [{"target": "example.cbor#GetThing"}, {"target": "example.cbor#PutThing"}],
                  "traits": { \(serviceTraits) }
                },
                "example.cbor#GetThing": {
                  "type": "operation",
                  "input": {"target": "example.cbor#GetThingInput"},
                  "output": {"target": "example.cbor#GetThingOutput"},
                  "traits": {"smithy.api#http": {"method": "GET", "uri": "/things/{thingId}", "code": 200}}
                },
                "example.cbor#PutThing": {
                  "type": "operation",
                  "input": {"target": "example.cbor#PutThingInput"},
                  "traits": {
                    "smithy.api#http": {"method": "PUT", "uri": "/", "code": 200},
                    "smithy.api#endpoint": {"hostPrefix": "{accountId}."}
                  }
                },
                "example.cbor#PutThingInput": {
                  "type": "structure",
                  "members": {
                    "accountId": {
                      "target": "smithy.api#String",
                      "traits": {"smithy.api#required": {}, "smithy.api#hostLabel": {}}
                    },
                    "value": {"target": "smithy.api#String"}
                  }
                },
                "example.cbor#GetThingInput": {
                  "type": "structure",
                  "members": {
                    "thingId": {
                      "target": "smithy.api#String",
                      "traits": {"smithy.api#required": {}, "smithy.api#httpLabel": {}}
                    },
                    "trace": {
                      "target": "smithy.api#String",
                      "traits": {"smithy.api#httpHeader": "X-Trace"}
                    },
                    "filter": {
                      "target": "smithy.api#String",
                      "traits": {"smithy.api#httpQuery": "filter"}
                    },
                    "since": {
                      "target": "smithy.api#Timestamp",
                      "traits": {"smithy.api#httpQuery": "since", "smithy.api#timestampFormat": "date-time"}
                    },
                    "note": {
                      "target": "smithy.api#String",
                      "traits": {"smithy.api#jsonName": "NOTE"}
                    }
                  }
                },
                "example.cbor#GetThingOutput": {
                  "type": "structure",
                  "members": {
                    "etag": {
                      "target": "smithy.api#String",
                      "traits": {"smithy.api#httpHeader": "ETag"}
                    },
                    "name": {"target": "smithy.api#String"},
                    "updated": {
                      "target": "smithy.api#Timestamp",
                      "traits": {"smithy.api#timestampFormat": "http-date"}
                    }
                  }
                }
              }
            }
            """
    }

    private static func service(protocolTraits: [String]) throws -> AwsService {
        _ = Self.registered
        let data = Data(Self.modelJSON(protocolTraits: protocolTraits).utf8)
        let model = try Smithy().decodeAST(from: data)
        try model.validate()
        return try AwsService(
            model,
            endpoints: .init(partitions: []),
            filter: nil,
            outputHTMLComments: false,
            logger: Logger(label: "RpcV2CborTests")
        )
    }

    /// The generated source of one structure, from its declaration up to the next declaration
    private static func section(of structure: String, in source: String) throws -> String {
        let start = try #require(source.range(of: "struct \(structure):"))
        let rest = source[start.lowerBound...].dropFirst()
        let end = rest.range(of: "public struct ")?.lowerBound ?? rest.endIndex
        return String(source[start.lowerBound..<end])
    }

    private static func render(_ service: AwsService) throws -> (api: String, shapes: String) {
        let library = try Templates.createLibrary()
        let api = try #require(library.render(try service.generateServiceContext(), withTemplate: "api"))
        let shapes = try #require(library.render(try service.generateShapesContext(), withTemplate: "shapes"))
        return (api, shapes)
    }

    @Test("rpcv2Cbor as the only protocol is selected")
    func onlyProtocol() throws {
        let service = try Self.service(protocolTraits: ["smithy.protocols#rpcv2Cbor"])
        #expect(service.serviceProtocolTrait is SmithyProtocolsRpcv2CborTrait)
    }

    @Test("service config gets the service shape name without the namespace")
    func serviceConfig() throws {
        let output = try Self.render(try Self.service(protocolTraits: ["smithy.protocols#rpcv2Cbor"]))
        #expect(output.api.contains("serviceProtocol: .rpcv2Cbor(serviceName: \"CborTest\")"))
        #expect(!output.api.contains("amzTarget"))
    }

    @Test("operations are POST to the root path whatever the http trait says")
    func operationRequest() throws {
        let output = try Self.render(try Self.service(protocolTraits: ["smithy.protocols#rpcv2Cbor"]))
        #expect(output.api.contains("path: \"/\""))
        #expect(output.api.contains("httpMethod: .post"))
        #expect(!output.api.contains("/things/"))
        #expect(!output.api.contains("httpMethod: .get"))
    }

    @Test("every input member is a body key and nothing is written to headers, query or path")
    func inputShape() throws {
        let output = try Self.render(try Self.service(protocolTraits: ["smithy.protocols#rpcv2Cbor"]))
        let shapes = output.shapes
        #expect(shapes.contains("case thingId = \"thingId\""))
        #expect(shapes.contains("case trace = \"trace\""))
        #expect(shapes.contains("case filter = \"filter\""))
        #expect(shapes.contains("case since = \"since\""))
        // jsonName is not used by RPC v2
        #expect(shapes.contains("case note = \"note\""))
        #expect(!shapes.contains("NOTE"))
        #expect(!shapes.contains("request.encodeHeader"))
        #expect(!shapes.contains("request.encodeQuery"))
        #expect(!shapes.contains("request.encodePath"))
        #expect(!shapes.contains("X-Trace"))
        // all members are plain Codable so the synthesized encode(to:) writes them all
        #expect(!(try Self.section(of: "GetThingInput", in: shapes)).contains("func encode(to encoder: Encoder)"))
    }

    @Test("a hostLabel member feeds the endpoint prefix and is also written to the body")
    func hostLabel() throws {
        let output = try Self.render(try Self.service(protocolTraits: ["smithy.protocols#rpcv2Cbor"]))
        let shape = try Self.section(of: "PutThingInput", in: output.shapes)
        #expect(shape.contains("case accountId = \"accountId\""))
        #expect(shape.contains("try container.encode(self.accountId, forKey: .accountId)"))
        #expect(shape.contains("request.encodeHostPrefix(self.accountId, key: \"accountId\")"))
        #expect(output.api.contains("hostPrefix: \"{accountId}.\""))
    }

    @Test("a shape finds the request container through the encoder accessor, not userInfo")
    func requestContainerAccessor() throws {
        let output = try Self.render(try Self.service(protocolTraits: ["smithy.protocols#rpcv2Cbor"]))
        let shape = try Self.section(of: "PutThingInput", in: output.shapes)
        #expect(shape.contains("let request = try encoder.requireAWSRequestContainer()"))
        #expect(!output.shapes.contains("userInfo"))
    }

    @Test("every output member is read from the body")
    func outputShape() throws {
        let output = try Self.render(try Self.service(protocolTraits: ["smithy.protocols#rpcv2Cbor"]))
        let shapes = output.shapes
        #expect(shapes.contains("case etag = \"etag\""))
        #expect(shapes.contains("case name = \"name\""))
        #expect(shapes.contains("case updated = \"updated\""))
        #expect(!shapes.contains("decodeHeader"))
        #expect(!shapes.contains("ResponseDecodingContainer"))
    }

    @Test("timestamps use the default Date encoding, not a format coder")
    func timestamps() throws {
        let output = try Self.render(try Self.service(protocolTraits: ["smithy.protocols#rpcv2Cbor"]))
        #expect(!output.shapes.contains("ISO8601DateCoder"))
        #expect(!output.shapes.contains("UnixEpochDateCoder"))
        #expect(!output.shapes.contains("HTTPHeaderDateCoder"))
        #expect(output.shapes.contains("var since: Date?") || output.shapes.contains("let since: Date?"))
    }

    @Test("awsJson1_1 is kept when the service also lists rpcv2Cbor")
    func awsJsonWins() throws {
        let service = try Self.service(protocolTraits: ["aws.protocols#awsJson1_1", "smithy.protocols#rpcv2Cbor"])
        #expect(service.serviceProtocolTrait is AwsProtocolsAwsJson1_1Trait)
        let output = try Self.render(service)
        #expect(output.api.contains("serviceProtocol: .json(version: \"1.1\")"))
        #expect(output.api.contains("amzTarget: \"CborTest\""))
        #expect(!output.api.contains("rpcv2Cbor"))
        // HTTP bindings still apply to the JSON protocol
        #expect(output.shapes.contains("request.encodeHeader"))
    }

    @Test("awsQuery is kept when the service also lists rpcv2Cbor")
    func awsQueryWins() throws {
        let service = try Self.service(protocolTraits: ["smithy.protocols#rpcv2Cbor", "aws.protocols#awsQuery"])
        #expect(service.serviceProtocolTrait is AwsProtocolsAwsQueryTrait)
    }
}
