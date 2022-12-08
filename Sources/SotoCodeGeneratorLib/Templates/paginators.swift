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
    static let paginatorTemplate = #"""
    {{%CONTENT_TYPE:TEXT}}
    // MARK: Paginators

    extension {{name}} {
    {{#paginators}}
    {{#operation.comment}}
        ///  {{.}}
    {{/operation.comment}}
        ///
        /// Provide paginated results to closure `onPage` for it to combine them into one result.
        /// This works in a similar manner to `Array.reduce<Result>(_:_:) -> Result`.
        ///
        /// Parameters:
        ///   - input: Input for request
        ///   - initialValue: The value to use as the initial accumulating value. `initialValue` is passed to `onPage` the first time it is called.
        ///   - logger: Logger used flot logging
        ///   - eventLoop: EventLoop to run this process on
        ///   - onPage: closure called with each paginated response. It combines an accumulating result with the contents of response. This combined result is then returned
        ///         along with a boolean indicating if the paginate operation should continue.
    {{#operation.deprecated}}
        @available(*, deprecated, message:"{{.}}")
    {{/operation.deprecated}}
        {{scope}} func {{operation.funcName}}Paginator<Result>(
            _ input: {{operation.inputShape}},
            _ initialValue: Result,
            logger: {{logger}} = AWSClient.loggingDisabled,
            on eventLoop: EventLoop? = nil,
            onPage: @escaping (Result, {{operation.outputShape}}, EventLoop) -> EventLoopFuture<(Bool, Result)>
        ) -> EventLoopFuture<Result> {
            return client.paginate(
                input: input,
                initialValue: initialValue,
                command: {{operation.funcName}},
    {{#inputKey}}
                inputKey: \{{operation.inputShape}}.{{.}},
                outputKey: \{{operation.outputShape}}.{{outputKey}},
    {{/inputKey}}
    {{^inputKey}}
                tokenKey: \{{operation.outputShape}}.{{outputKey}},
    {{#moreResultsKey}}
                moreResultsKey: \{{operation.outputShape}}.{{.}},
    {{/moreResultsKey}}
    {{/inputKey}}
                on: eventLoop,
                onPage: onPage
            )
        }

        /// Provide paginated results to closure `onPage`.
        ///
        /// - Parameters:
        ///   - input: Input for request
        ///   - logger: Logger used flot logging
        ///   - eventLoop: EventLoop to run this process on
        ///   - onPage: closure called with each block of entries. Returns boolean indicating whether we should continue.
    {{#operation.deprecated}}
        @available(*, deprecated, message:"{{.}}")
    {{/operation.deprecated}}
        {{scope}} func {{operation.funcName}}Paginator(
            _ input: {{operation.inputShape}},
            logger: {{logger}} = AWSClient.loggingDisabled,
            on eventLoop: EventLoop? = nil,
            onPage: @escaping ({{operation.outputShape}}, EventLoop) -> EventLoopFuture<Bool>
        ) -> EventLoopFuture<Void> {
            return client.paginate(
                input: input,
                command: {{operation.funcName}},
    {{#inputKey}}
                inputKey: \{{operation.inputShape}}.{{.}},
                outputKey: \{{operation.outputShape}}.{{outputKey}},
    {{/inputKey}}
    {{^inputKey}}
                tokenKey: \{{operation.outputShape}}.{{outputKey}},
    {{#moreResultsKey}}
                moreResultsKey: \{{operation.outputShape}}.{{.}},
    {{/moreResultsKey}}
    {{/inputKey}}
                on: eventLoop,
                onPage: onPage
            )
        }
    {{^last()}}

    {{/last()}}
    {{/paginators}}
    }

    {{#paginatorShapes}}
    extension {{name}}.{{inputShape}}: {{paginatorProtocol}} {
        {{scope}} func usingPaginationToken(_ token: {{tokenType}}) -> {{name}}.{{inputShape}} {
            return .init(
    {{#initParams}}
                {{.}}{{^last()}},{{/last()}}
    {{/initParams}}
            )
        }
    }
    {{^last()}}

    {{/last()}}
    {{/paginatorShapes}}
    """#
}
