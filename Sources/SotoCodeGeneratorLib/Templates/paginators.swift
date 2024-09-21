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
    static let paginatorTemplate = #"""
    {{%CONTENT_TYPE:TEXT}}
    // MARK: Paginators

    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    extension {{name}} {
    {{#paginators}}
        /// Return PaginatorSequence for operation ``{{operation.funcName}}(_:logger:)``.
        ///
        /// - Parameters:
        ///   - input: Input for request
        ///   - logger: Logger used for logging
    {{#operation.deprecated}}
        @available(*, deprecated, message: "{{.}}")
    {{/operation.deprecated}}
        @inlinable
        {{scope}} func {{operation.funcName}}Paginator(
            _ input: {{operation.inputShape}},
            logger: {{logger}} = AWSClient.loggingDisabled
        ) -> AWSClient.PaginatorSequence<{{operation.inputShape}}, {{operation.outputShape}}> {
            return .init(
                input: input,
                command: self.{{operation.funcName}},
    {{#inputKey}}
                inputKey: \{{operation.inputShape}}.{{.}},
    {{/inputKey}}
                outputKey: \{{operation.outputShape}}.{{outputKey}},
    {{#moreResultsKey}}
                moreResultsKey: \{{operation.outputShape}}.{{.}},
    {{/moreResultsKey}}
                logger: logger
            )
        }
    {{#operation}}    
    {{#inputShape}}
        /// Return PaginatorSequence for operation ``{{operation.funcName}}(_:logger:)``.
        ///
        /// - Parameters:
        {{#initParameters}}
        ///   - {{parameter}}: {{first(comment)}}
        {{/initParameters}}
        ///   - logger: Logger used for logging
    {{#deprecated}}
        @available(*, deprecated, message: "{{.}}")
    {{/deprecated}}
        @inlinable
        {{scope}} func {{funcName}}Paginator(
            {{#initParameters}}
            {{parameter}}: {{type}}{{#default}} = {{.}}{{/default}},
            {{/initParameters}}
            logger: {{logger}} = AWSClient.loggingDisabled        
        ) -> AWSClient.PaginatorSequence<{{operation.inputShape}}, {{operation.outputShape}}> {
            let input = {{inputShape}}(
    {{^empty(initParameters)}}
            {{#initParameters}}
                {{parameter}}: {{variable}}{{^last()}}, {{/last()}}
            {{/initParameters}}
    {{/empty(initParameters)}}
            )
            return self.{{funcName}}Paginator(input, logger: logger)
        }
    {{/inputShape}}
    {{/operation}}    
    {{^last()}}

    {{/last()}}
    {{/paginators}}
    }

    {{#paginatorShapes}}
    extension {{name}}.{{inputShape}}: {{paginatorProtocol}} {
        @inlinable
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
