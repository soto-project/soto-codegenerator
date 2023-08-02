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

extension Templates {
    static let apiTemplate = #"""
    {{%CONTENT_TYPE:TEXT}}
    {{>header}}

    @_exported import SotoCore

    {{#middlewareFramework}}
    import {{ . }}

    {{/middlewareFramework}}
    /// Service object for interacting with AWS {{name}} service.
    {{#first(description)}}
    ///
    {{#description}}
    {{>comment}}
    {{/description}}
    {{/first(description)}}
    {{scope}} struct {{ name }}: AWSService {
        // MARK: Member variables

        /// Client used for communication with AWS
        {{scope}} let client: AWSClient
        /// Service configuration
        {{scope}} let config: AWSServiceConfig
    {{#endpointDiscovery}}
        /// endpoint storage
        let endpointStorage: AWSEndpointStorage
    {{/endpointDiscovery}}

        // MARK: Initialization

        /// Initialize the {{name}} client
        /// - parameters:
        ///     - client: AWSClient used to process requests
    {{#regionalized}}
        ///     - region: Region of server you want to communicate with. This will override the partition parameter.
    {{/regionalized}}
        ///     - partition: AWS partition where service resides, standard (.aws), china (.awscn), government (.awsusgov).
        ///     - endpoint: Custom endpoint URL to use instead of standard AWS servers
    {{^middlewareClass}}
        ///     - middleware: Middleware chain used to edit requests before they are sent and responses before they are decoded 
    {{/middlewareClass}}
        ///     - timeout: Timeout value for HTTP requests
        ///     - byteBufferAllocator: Allocator for ByteBuffers
        ///     - options: Service options
        {{scope}} init(
            client: AWSClient,
    {{#regionalized}}
            region: SotoCore.Region? = nil,
    {{/regionalized}}
            partition: AWSPartition = .aws,
            endpoint: String? = nil,
    {{^middlewareClass}}
            middleware: AWSMiddlewareProtocol? = nil,
    {{/middlewareClass}}
            timeout: TimeAmount? = nil,
            byteBufferAllocator: ByteBufferAllocator = ByteBufferAllocator(),
            options: AWSServiceConfig.Options = []
        ) {
            self.client = client
            self.config = AWSServiceConfig(
    {{#regionalized}}
                region: region,
                partition: region?.partition ?? partition,
    {{/regionalized}}
    {{^regionalized}}
                region: nil,
                partition: partition,
    {{/regionalized}}
    {{#amzTarget}}
                amzTarget: "{{.}}",
    {{/amzTarget}}
                service: "{{endpointPrefix}}",
    {{#signingName}}
                signingName: "{{.}}",
    {{/signingName}}
                serviceProtocol: {{protocol}},
                apiVersion: "{{apiVersion}}",
                endpoint: endpoint,
    {{#first(serviceEndpoints)}}
                serviceEndpoints: Self.serviceEndpoints,
    {{/first(serviceEndpoints)}}
    {{#first(partitionEndpoints)}}
                partitionEndpoints: Self.partitionEndpoints,
    {{/first(partitionEndpoints)}}
    {{#first(variantEndpoints)}}
                variantEndpoints: Self.variantEndpoints,
    {{/first(variantEndpoints)}}
    {{#errorTypes}}
                errorType: {{.}}.self,
    {{/errorTypes}}
    {{#xmlNamespace}}
                xmlNamespace: "{{.}}",
    {{/xmlNamespace}}
    {{^middlewareClass}}
                middleware: middleware,
    {{/middlewareClass}}
                timeout: timeout,
                byteBufferAllocator: byteBufferAllocator,
                options: options
            )
            {{#endpointDiscovery}}
            self.endpointStorage = .init()
            {{/endpointDiscovery}}
        }

    {{#middlewareClass}}
        /// Initialize the {{name}} client
        /// - parameters:
        ///     - client: AWSClient used to process requests
    {{#regionalized}}
        ///     - region: Region of server you want to communicate with. This will override the partition parameter.
    {{/regionalized}}
        ///     - partition: AWS partition where service resides, standard (.aws), china (.awscn), government (.awsusgov).
        ///     - endpoint: Custom endpoint URL to use instead of standard AWS servers
        ///     - middleware: Middleware chain used to edit requests before they are sent and responses before they are decoded 
        ///     - timeout: Timeout value for HTTP requests
        ///     - byteBufferAllocator: Allocator for ByteBuffers
        ///     - options: Service options
        {{scope}} init(
            client: AWSClient,
    {{#regionalized}}
            region: SotoCore.Region? = nil,
    {{/regionalized}}
            partition: AWSPartition = .aws,
            endpoint: String? = nil,
            middleware: some AWSMiddlewareProtocol,
            timeout: TimeAmount? = nil,
            byteBufferAllocator: ByteBufferAllocator = ByteBufferAllocator(),
            options: AWSServiceConfig.Options = []
        ) {
            self.client = client
            self.config = AWSServiceConfig(
    {{#regionalized}}
                region: region,
                partition: region?.partition ?? partition,
    {{/regionalized}}
    {{^regionalized}}
                region: nil,
                partition: partition,
    {{/regionalized}}
    {{#amzTarget}}
                amzTarget: "{{.}}",
    {{/amzTarget}}
                service: "{{endpointPrefix}}",
    {{#signingName}}
                signingName: "{{.}}",
    {{/signingName}}
                serviceProtocol: {{protocol}},
                apiVersion: "{{apiVersion}}",
                endpoint: endpoint,
    {{#first(serviceEndpoints)}}
                serviceEndpoints: Self.serviceEndpoints,
    {{/first(serviceEndpoints)}}
    {{#first(partitionEndpoints)}}
                partitionEndpoints: Self.partitionEndpoints,
    {{/first(partitionEndpoints)}}
    {{#first(variantEndpoints)}}
                variantEndpoints: Self.variantEndpoints,
    {{/first(variantEndpoints)}}
    {{#errorTypes}}
                errorType: {{.}}.self,
    {{/errorTypes}}
    {{#xmlNamespace}}
                xmlNamespace: "{{.}}",
    {{/xmlNamespace}}
                middleware: AWSMiddlewareStack {
                    middleware
                    {{middlewareClass}}
                },
                timeout: timeout,
                byteBufferAllocator: byteBufferAllocator,
                options: options
            )
            {{#endpointDiscovery}}
            self.endpointStorage = .init()
            {{/endpointDiscovery}}
        }
    {{/middlewareClass}}

    {{#first(serviceEndpoints)}}
        /// custom endpoints for regions
        static var serviceEndpoints: [String: String] {[
    {{#serviceEndpoints}}
            {{.}}{{^last()}},{{/last()}}
    {{/serviceEndpoints}}
        ]}
    {{/first(serviceEndpoints)}}

    {{#first(partitionEndpoints)}}
        /// Default endpoint and region to use for each partition
        static var partitionEndpoints: [AWSPartition: (endpoint: String, region: SotoCore.Region)] {[
    {{#partitionEndpoints}}
            {{.}}{{^last()}},{{/last()}}
    {{/partitionEndpoints}}
        ]}
    {{/first(partitionEndpoints)}}

    {{#first(variantEndpoints)}}
        /// FIPS and dualstack endpoints
        static var variantEndpoints: [EndpointVariantType: AWSServiceConfig.EndpointVariant] {[
    {{#variantEndpoints}}
            [{{variant}}]: .init(endpoints: [
    {{#endpoints.endpoints}}
                "{{region}}": "{{hostname}}"{{^last()}},{{/last()}}
    {{/endpoints.endpoints}}
            ]){{^last()}},{{/last()}}
    {{/variantEndpoints}}
        ]}
    {{/first(variantEndpoints)}}

        // MARK: API Calls
    {{#operations}}

    {{#comment}}
        {{>comment}}
    {{/comment}}
    {{#documentationUrl}}
        /// {{.}}
    {{/documentationUrl}}
    {{#deprecated}}
        @available(*, deprecated, message: "{{.}}")
    {{/deprecated}}
        @Sendable
        {{scope}} func {{funcName}}({{#inputShape}}_ input: {{.}}, {{/inputShape}}logger: {{logger}} = AWSClient.loggingDisabled) async throws{{#outputShape}} -> {{.}}{{/outputShape}} {
            return try await self.client.execute(
                operation: "{{name}}", 
                path: "{{path}}", 
                httpMethod: .{{httpMethod}}, 
                serviceConfig: self.config{{#endpointRequired}}
                    .with(middleware: EndpointDiscoveryMiddleware(storage: self.endpointStorage, discover: self.getEndpoint, required: {{required}})
                ){{/endpointRequired}}{{#inputShape}}, 
                input: input{{/inputShape}}{{#hostPrefix}}, 
                hostPrefix: "{{{.}}}"{{/hostPrefix}}, 
                logger: logger
            )
        }
    {{/operations}}
    {{#endpointDiscovery}}

        @Sendable func getEndpoint(logger: Logger) async throws -> AWSEndpoints {
            let response = try await self.describeEndpoints(.init(), logger: logger)
            return .init(endpoints: response.endpoints.map {
                .init(address: "https://\($0.address)", cachePeriodInMinutes: $0.cachePeriodInMinutes)
            })
        }
    {{/endpointDiscovery}}
    }

    extension {{ name }} {
        /// Initializer required by `AWSService.with(middlewares:timeout:byteBufferAllocator:options)`. You are not able to use this initializer directly as there are not public
        /// initializers for `AWSServiceConfig.Patch`. Please use `AWSService.with(middlewares:timeout:byteBufferAllocator:options)` instead.
        {{scope}} init(from: {{ name }}, patch: AWSServiceConfig.Patch) {
            self.client = from.client
            self.config = from.config.with(patch: patch)
        {{#endpointDiscovery}}
            self.endpointStorage = .init()
        {{/endpointDiscovery}}
        }
    }
    {{#paginators}}

    {{>paginators}}
    {{/paginators}}
    {{#waiters}}

    {{>waiters}}
    {{/waiters}}

    """#
}
