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

extension Templates {
    static let waiterTemplate = """
    {{%CONTENT_TYPE:TEXT}}
    {{>header}}

    @_exported import SotoCore

    import SotoCore

    // MARK: Waiters

    extension {{name}} {
    {{#waiters}}
    {{#comment}}
        /// {{.}}
    {{/comment}}
    {{#deprecated}}
        @available(*, deprecated)
    {{/deprecated}}
        public func waitUntil{{waiterName}}(
            _ input: {{operation.inputShape}},
            maxWaitTime: TimeAmount? = nil,
            logger: Logger = AWSClient.loggingDisabled,
            on eventLoop: EventLoop? = nil
        ) -> EventLoopFuture<Void> {
            let waiter = AWSClient.Waiter(
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
                command: {{operation.funcName}}
            )
            return self.client.waitUntil(input, waiter: waiter, maxWaitTime: maxWaitTime, logger: logger, on: eventLoop)
        }
    {{^last()}}

    {{/last()}}
    {{/waiters}}
    }
    """
}
