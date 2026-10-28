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
    static let errorTemplate = #"""
        {{%CONTENT_TYPE:TEXT}}
        // MARK: - Errors

        /// Error enum for {{name}}
        {{#withAssociatedValues}}
        {{scope}} struct {{errorName}}: AWSErrorType, Decodable {
            @nonexhaustive
            {{scope}} enum Code: Sendable {
        {{#errors}}
        {{#comment}}
                {{>comment}}
        {{/comment}}
                case {{enum}}{{#associatedType}}({{name}}.{{.}}){{/associatedType}}
        {{/errors}}
            }
        {{/withAssociatedValues}}
        {{^withAssociatedValues}}
        {{scope}} struct {{errorName}}: AWSErrorType, Decodable {
            @nonexhaustive
            {{scope}} enum Code: String, Sendable, Equatable {
        {{#errors}}
        {{#comment}}
                {{>comment}}
        {{/comment}}
                case {{enum}} = "{{string}}"
        {{/errors}}
            }
        {{/withAssociatedValues}}

            {{scope}} let error: Code
            {{scope}} let message: String?
            {{scope}} let response: HTTPResponse?

            {{scope}} init(from decoder: any Decoder) throws {
                let singleValueContainer = try decoder.singleValueContainer()
                let responseError = try singleValueContainer.decode(AWSResponseError.self)
        {{#withAssociatedValues}}
                switch responseError.errorCode {
        {{#errors}}
        {{#associatedType}}
                case "{{string}}":
                    let context = try singleValueContainer.decode({{name}}.{{.}}.self)
                    self.error = .{{enum}}(context)
        {{/associatedType}}
        {{^associatedType}}
                case "{{string}}": self.error = .{{enum}}
        {{/associatedType}}
        {{/errors}}
                default:
        {{/withAssociatedValues}}
        {{^withAssociatedValues}}
                if let code = Code(rawValue: responseError.errorCode) {
                    self.error = code
                } else {
        {{/withAssociatedValues}}
                    throw responseError
                }
                self.message = responseError.message
                self.response = responseError.response
            }

        {{#withAssociatedValues}}
            /// return error code string
            {{scope}} var errorCode: String {
                switch error {
        {{#errors}}
                case .{{enum}}: "{{string}}"
        {{/errors}}
                }
            }
        {{/withAssociatedValues}}
        {{^withAssociatedValues}}
            {{scope}} var errorCode: String { self.error.rawValue }
        {{/withAssociatedValues}}
        }

        """#
}
