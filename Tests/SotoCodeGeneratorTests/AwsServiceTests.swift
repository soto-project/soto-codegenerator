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

import Logging
import SotoSmithy
import SotoSmithyAWS
import XCTest

@testable import SotoCodeGeneratorLib

final class AwsServiceTests: XCTestCase {
    func testEndpointEnvironmentVariable() {
        XCTAssertEqual(AwsService.endpointEnvironmentVariable(sdkId: "CloudWatch"), "AWS_ENDPOINT_URL_CLOUDWATCH")
        XCTAssertEqual(AwsService.endpointEnvironmentVariable(sdkId: "API Gateway"), "AWS_ENDPOINT_URL_API_GATEWAY")
    }

    func testEndpointEnvironmentVariableUsesSDKID() throws {
        Smithy.registerAWSTraits()
        let json = """
            {
                "smithy": "2.0",
                "shapes": {
                    "com.amazonaws.elasticloadbalancing#ElasticLoadBalancing_v7": {
                        "type": "service",
                        "version": "2026-01-01",
                        "traits": {
                            "aws.api#service": {"sdkId": "Elastic Load Balancing", "endpointPrefix": "elasticloadbalancing"},
                            "aws.protocols#awsQuery": {}
                        }
                    }
                }
            }
            """
        let model = try Smithy().decodeAST(from: Data(json.utf8))
        let service = try AwsService(
            model,
            endpoints: .init(partitions: []),
            filter: nil,
            outputHTMLComments: false,
            logger: Logger(label: "test")
        )
        let context = try service.generateServiceContext()
        XCTAssertEqual(service.serviceName, "ElasticLoadBalancing")
        XCTAssertEqual(context["endpointEnvironmentVariable"] as? String, "AWS_ENDPOINT_URL_ELASTIC_LOAD_BALANCING")
    }

    func testEndpointEnvironmentVariableSurvivesSDKIDPatch() throws {
        Smithy.registerAWSTraits()
        let model = try Smithy().parse(
            """
            namespace com.amazonaws.ecrpublic
            @aws.api#service(sdkId: "ECR PUBLIC", endpointPrefix: "api.ecr-public")
            @aws.protocols#restJson1
            service SpencerFrontendService { version: "2026-01-01" }
            """
        )
        let service = try AwsService(
            model,
            endpoints: .init(partitions: []),
            filter: nil,
            outputHTMLComments: false,
            logger: Logger(label: "test")
        )
        let context = try service.generateServiceContext()
        XCTAssertEqual(service.service.trait(type: AwsServiceTrait.self)?.sdkId, "ECRPublic")
        XCTAssertEqual(context["endpointEnvironmentVariable"] as? String, "AWS_ENDPOINT_URL_ECR_PUBLIC")
    }

    func testServiceEndpointTemplate() throws {
        let library = try Templates.createLibrary()
        var context = ["name": "CloudWatch", "endpointEnvironmentVariable": "AWS_ENDPOINT_URL_CLOUDWATCH"]
        let lookup = #"endpoint: endpoint ?? ProcessInfo.processInfo.environment["AWS_ENDPOINT_URL_CLOUDWATCH"]"#
        let source = try XCTUnwrap(library.render(context, withTemplate: "api"))
        XCTAssertEqual(source.components(separatedBy: lookup).count - 1, 1)

        context["middlewareClass"] = "CustomMiddleware"
        let middlewareSource = try XCTUnwrap(library.render(context, withTemplate: "api"))
        XCTAssertEqual(middlewareSource.components(separatedBy: lookup).count - 1, 2)
    }
}
