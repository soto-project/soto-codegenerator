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
    static let enumTemplate = """
    {{%CONTENT_TYPE:TEXT}}
    {{#isExtensible}}
        {{scope}} struct {{name}}: RawRepresentable, Equatable, Codable, _SotoSendable {
            {{scope}} var rawValue: String

            {{scope}} init(rawValue: String) {
                self.rawValue = rawValue
            }
    {{#values}}
    {{#documentation}}
            /// {{.}}
    {{/documentation}}
            {{scope}} static var {{case}}: Self { .init(rawValue: "{{string}}")}
    {{/values}}
        }

    {{/isExtensible}}
    {{^isExtensible}}
        {{scope}} enum {{name}}: String, CustomStringConvertible, Codable, _SotoSendable {
    {{#values}}
    {{#documentation}}
            /// {{.}}
    {{/documentation}}
            case {{case}} = "{{string}}"
    {{/values}}
            {{scope}} var description: String { return self.rawValue }
        }
    {{/isExtensible}}
    """
}
