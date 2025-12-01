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
    static let enumTemplate = """
        {{%CONTENT_TYPE:TEXT}}
        {{#isExtensible}}
            {{scope}} struct {{name}}: RawRepresentable, Equatable, Codable, Sendable, CodingKeyRepresentable {
                {{scope}} var rawValue: String

                {{scope}} init(rawValue: String) {
                    self.rawValue = rawValue
                }

        {{#stringValues.values}}
        {{#documentation}}
                {{>comment}}
        {{/documentation}}
                {{scope}} static var {{case}}: Self { .init(rawValue: "{{rawValue}}") }
        {{/stringValues.values}}
            }
        {{/isExtensible}}
        {{^isExtensible}}
        {{#stringValues}}
            {{scope}} enum {{name}}: String, CustomStringConvertible, Codable, Sendable, CodingKeyRepresentable {
        {{#values}}
        {{#documentation}}
                {{>comment}}
        {{/documentation}}
                case {{case}} = "{{rawValue}}"
        {{/values}}
                {{scope}} var description: String { return self.rawValue }
            }
        {{/stringValues}}
        {{#intValues}}
            {{scope}} enum {{name}}: Int, CustomStringConvertible, Codable, Sendable, CodingKeyRepresentable {
        {{#values}}
        {{#documentation}}
                {{>comment}}
        {{/documentation}}
                case {{case}} = {{rawValue}}
        {{/values}}
                {{scope}} var description: String { return "\\(self.rawValue)" }
            }
        {{/intValues}}
        {{/isExtensible}}

        """
}
