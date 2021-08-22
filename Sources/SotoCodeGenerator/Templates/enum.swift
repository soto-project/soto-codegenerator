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
        public struct {{name}}: RawRepresentable, Equatable, Codable {
            public var rawValue: String

            public init(rawValue: String) {
                self.rawValue = rawValue
            }
    {{#values}}
    {{#documentation}}
            /// {{.}}
    {{/documentation}}
            public static var {{case}}: Self { .init(rawValue: "{{string}}")}
    {{/values}}
        }

    {{/isExtensible}}
    {{^isExtensible}}
        public enum {{name}}: String, CustomStringConvertible, Codable {
    {{#values}}
    {{#documentation}}
            /// {{.}}
    {{/documentation}}
            case {{case}} = "{{string}}"
    {{/values}}
            public var description: String { return self.rawValue }
        }
    {{/isExtensible}}
    """
}
