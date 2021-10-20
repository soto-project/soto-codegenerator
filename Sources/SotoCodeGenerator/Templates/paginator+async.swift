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
    static let paginatorAsyncTemplate = #"""
    {{%CONTENT_TYPE:TEXT}}
    {{>header}}

    #if compiler(>=5.5) && canImport(_Concurrency)

    import SotoCore

    // MARK: Paginators

    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    extension {{name}} {
    {{#paginators}}
    {{#operation.comment}}
        ///  {{.}}
    {{/operation.comment}}
        /// Return PaginatorSequence for operation.
        ///
        /// - Parameters:
        ///   - input: Input for request
        ///   - logger: Logger used flot logging
        ///   - eventLoop: EventLoop to run this process on
    {{#operation.deprecated}}
        @available(*, deprecated, message:"{{.}}")
    {{/operation.deprecated}}
        public func {{operation.funcName}}Paginator(
            _ input: {{operation.inputShape}},
            logger: {{logger}} = AWSClient.loggingDisabled,
            on eventLoop: EventLoop? = nil
        ) -> AWSClient.PaginatorSequence<{{operation.inputShape}}, {{operation.outputShape}}> {
            return .init(
                input: input,
                command: {{operation.funcName}},
    {{#inputKey}}
                inputKey: \{{operation.inputShape}}.{{.}},
    {{/inputKey}}
                outputKey: \{{operation.outputShape}}.{{outputKey}},
    {{#moreResultsKey}}
                moreResultsKey: \{{operation.outputShape}}.{{.}},
    {{/moreResultsKey}}
                logger: logger,
                on: eventLoop
            )
        }
    {{^last()}}

    {{/last()}}
    {{/paginators}}
    }

    #endif // compiler(>=5.5) && canImport(_Concurrency)
    """#
}
