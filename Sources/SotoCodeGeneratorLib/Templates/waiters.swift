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
    static let waiterTemplate = """
    {{%CONTENT_TYPE:TEXT}}
    // MARK: Waiters

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    extension {{name}} {
    {{#waiters}}
        /// Waiter for operation ``{{operation.funcName}}(_:logger:)``.
        ///
        /// - Parameters:
        ///   - input: Input for operation
        ///   - logger: Logger used for logging
        @inlinable
        {{scope}} func waitUntil{{waiterName}}(
            _ input: {{operation.inputShape}},
            maxWaitTime: TimeAmount? = nil,
            logger: Logger = AWSClient.loggingDisabled
        ) async throws {
            let waiter = AWSClient.Waiter<{{operation.inputShape}}, _>(
                acceptors: [
    {{#acceptors}}
    {{#matcher.jmesPath}}
                    .init(state: .{{state}}, matcher: try! JMESPathMatcher("{{path}}", expected: {{expected}})),
    {{/matcher.jmesPath}}
    {{#matcher.jmesAnyPath}}
                    .init(state: .{{state}}, matcher: try! JMESAnyPathMatcher("{{path}}", expected: {{expected}})),
    {{/matcher.jmesAnyPath}}
    {{#matcher.jmesAllPath}}
                    .init(state: .{{state}}, matcher: try! JMESAllPathMatcher("{{path}}", expected: {{expected}})),
    {{/matcher.jmesAllPath}}
    {{#matcher.error}}
                    .init(state: .{{state}}, matcher: AWSErrorCodeMatcher("{{.}}")),
    {{/matcher.error}}
    {{#matcher.errorStatus}}
                    .init(state: .{{state}}, matcher: AWSErrorStatusMatcher({{.}})),
    {{/matcher.errorStatus}}
    {{#matcher.success}}
                    .init(state: .{{state}}, matcher: AWSSuccessMatcher()),
    {{/matcher.success}}
    {{/acceptors}}
                ],
    {{#minDelayTime}}
                minDelayTime: .seconds({{.}}),
    {{/minDelayTime}}
    {{#maxDelayTime}}
                maxDelayTime: .seconds({{.}}),
    {{/maxDelayTime}}
                command: self.{{operation.funcName}}
            )
            return try await self.client.waitUntil(input, waiter: waiter, maxWaitTime: maxWaitTime, logger: logger)
        }
    {{#inputKey}}
        /// Waiter for operation ``{{operation.funcName}}(_:logger:)``.
        ///
        /// - Parameters:
        {{#operation.initParameters}}
        ///   - {{parameter}}: {{first(comment)}}
        {{/operation.initParameters}}
        ///   - logger: Logger used for logging
        @inlinable
        {{scope}} func waitUntil{{waiterName}}(
            {{#operation.initParameters}}
            {{parameter}}: {{type}}{{#default}} = {{.}}{{/default}},
            {{/operation.initParameters}}
            logger: {{logger}} = AWSClient.loggingDisabled        
        ) async throws {
            let input = {{operation.inputShape}}(
            {{^empty(operation.initParameters)}}
            {{#operation.initParameters}}
                {{parameter}}: {{variable}}{{^last()}}, {{/last()}}
            {{/operation.initParameters}}
            {{/empty(operation.initParameters)}}
            )
            try await self.waitUntil{{waiterName}}(input, logger: logger)
        }
    {{/inputKey}}
    {{^last()}}

    {{/last()}}
    {{/waiters}}
    }

    """
}
