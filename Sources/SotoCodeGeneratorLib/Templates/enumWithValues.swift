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
    static let enumWithValuesTemplate = #"""
    {{! Template for a AWSShape enum with values }}
    {{%CONTENT_TYPE:TEXT}}
        {{scope}} {{object}} {{name}}: {{shapeProtocol}}, Sendable {
    {{#namespace}}
            {{scope}} static let _xmlNamespace: String? = "{{.}}"
    {{/namespace}}
    {{! AWSShapeMember array }}
    {{#first(awsShapeMembers)}}
            {{scope}} static var _encoding = [
    {{#awsShapeMembers}}
                AWSMemberEncoding(label: "{{name}}"{{#location}}, location: {{.}}{{/location}}){{^last()}}, {{/last()}}
    {{/awsShapeMembers}}
            ]

    {{/first(awsShapeMembers)}}
    {{! enum cases }}
    {{#members}}
    {{#comment}}
            {{>comment}}
    {{/comment}}
            case {{variable}}({{type}})
    {{/members}}
    {{#shapeCoding.requiresDecodeInit}}

            {{scope}} init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                guard container.allKeys.count == 1, let key = container.allKeys.first else {
                    let context = DecodingError.Context(
                        codingPath: container.codingPath,
                        debugDescription: "Expected exactly one key, but got \(container.allKeys.count)"
                    )
                    throw DecodingError.dataCorrupted(context)
                }
                switch key {
    {{#members}}
                case .{{variable}}:
                    let value = try container.decode({{type}}.self, forKey: .{{variable}})
                    self = .{{variable}}(value)
    {{/members}}
                }
            }
    {{/shapeCoding.requiresDecodeInit}}
    {{#shapeCoding.requiresEncode}}

            {{scope}} func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                switch self {
    {{#members}}
                case .{{variable}}(let value):
                    try container.encode(value, forKey: .{{variable}})
    {{/members}}
                }
            }
    {{/shapeCoding.requiresEncode}}

    {{! validate() function }}
    {{#first(validation)}}
            {{scope}} func validate(name: String) throws {
                switch self {
    {{#validation}}
                case .{{name}}(let value):
    {{#shape}}
                    try value.validate(name: "\(name).{{name}}")
    {{/shape}}
    {{! validate array members }}
    {{#.member}}
                    try value.forEach {
    {{#shape}}
                        try $0.validate(name: "\(name).{{name}}[]")
    {{/shape}}
    {{#sorted(reqs)}}
                        try validate($0, name: "{{name}}[]", parent: name, {{key}}: {{value}})
    {{/sorted(reqs)}}
                    }
    {{/.member}}
    {{! validate dictionary keys and possibly values }}
    {{#withDictionaryContexts(.)}}
                    try value.forEach {
    {{#.keyValidation}}
    {{#shape}}
                        try $0.validate(name: "\(name).{{name}}.key")
    {{/shape}}
    {{#sorted(reqs)}}
                        try validate($0.key, name: "{{name}}.key", parent: name, {{key}}: {{value}})
    {{/sorted(reqs)}}
    {{/.keyValidation}}
    {{! validate dictionary values }}
    {{#.valueValidation}}
    {{#shape}}
                        try $0.value.validate(name: "\(name).{{name}}[\"\($0.key)\"]")
    {{/shape}}
    {{#sorted(reqs)}}
                        try validate($0.value, name: "{{name}}[\"\($0.key)\"]", parent: name, {{key}}: {{value}})
    {{/sorted(reqs)}}
    {{/.valueValidation}}
                    }
    {{/withDictionaryContexts(.)}}
    {{! validate min,max,pattern }}
    {{#sorted(reqs)}}
                    try self.validate(value, name: "{{name}}", parent: name, {{key}}: {{value}})
    {{/sorted(reqs)}}
    {{/validation}}
    {{#requiresDefaultValidation}}
                default:
                    break
    {{/requiresDefaultValidation}}
                }
            }

    {{/first(validation)}}
    {{! CodingKeys enum }}
    {{#first(members)}}
    {{#empty(codingKeys)}}
            private enum CodingKeys: CodingKey {}
    {{/empty(codingKeys)}}
    {{^empty(codingKeys)}}
            private enum CodingKeys: String, CodingKey {
    {{#codingKeys}}
    {{#rawValue}}
                case {{variable}} = "{{.}}"
    {{/rawValue}}
    {{^rawValue}}
                case {{variable}}
    {{/rawValue}}
    {{/codingKeys}}
            }
    {{/empty(codingKeys)}}
    {{/first(members)}}
        }

    """#
}
