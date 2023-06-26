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
    static let structTemplate = #"""
    {{%CONTENT_TYPE:TEXT}}
    {{! Template for a AWSShape }}
        {{scope}} {{object}} {{name}}: {{shapeProtocol}} {
    {{#payload}}
            /// The key for the payload
            {{scope}} static let _payloadPath: String = "{{.}}"
    {{/payload}}
    {{#options}}
            {{scope}} static let _options: AWSShapeOptions = [{{.}}]
    {{/options}}
    {{#namespace}}
            {{scope}} static let _xmlNamespace: String? = "{{.}}"
    {{/namespace}}
    {{! AWSShapeMember array }}
    {{#first(awsShapeMembers)}}
            {{scope}} static var _encoding = [
    {{#awsShapeMembers}}
                AWSMemberEncoding(label: "{{name}}"{{#location}}, location: {{.}}{{/location}}){{^last()}},{{/last()}}
    {{/awsShapeMembers}}
            ]

    {{/first(awsShapeMembers)}}
    {{^empty(encoding)}}
    {{#encoding}}
    {{! Is encoding a dictionary }}
    {{#key}}
            {{scope}} struct {{name}}: DictionaryCoderProperties {
                {{scope}} static let entry: String? = {{#entry}}"{{.}}"{{/entry}}{{^entry}}nil{{/entry}}
                {{scope}} static let key = "{{key}}"
                {{scope}} static let value = "{{value}}"
            }
    {{/key}}
    {{^key}}
            {{scope}} struct {{name}}: ArrayCoderProperties { {{scope}} static let member = "{{member}}" }
    {{/key}}
    {{/encoding}}

    {{/empty(encoding)}}
    {{! Member variables }}
    {{^empty(members)}}
    {{#members}}
    {{#comment}}
            {{>comment}}
    {{/comment}}
    {{#propertyWrapper}}
            {{.}}
    {{/propertyWrapper}}
            {{scope}} {{#propertyWrapper}}var{{/propertyWrapper}}{{^propertyWrapper}}let{{/propertyWrapper}} {{variable}}: {{type}}
    {{/members}}

    {{/empty(members)}}
    {{! init() function }}
    {{#empty(members)}}
            {{scope}} init() {}
    {{/empty(members)}}
    {{^empty(members)}}
            {{scope}} init({{#initParameters}}{{parameter}}: {{type}}{{#default}} = {{.}}{{/default}}{{^last()}}, {{/last()}}{{/initParameters}}) {
    {{#members}}
    {{^deprecated}}
                self.{{variable}} = {{variable}}
    {{/deprecated}}
    {{#deprecated}}
                self.{{variable}} = {{default}}
    {{/deprecated}}
    {{/members}}
            }
    {{/empty(members)}}
    {{! deprecated init() function }}
    {{^empty(deprecatedMembers)}}

            @available(*, deprecated, message: "Members {{#deprecatedMembers}}{{.}}{{^last()}}, {{/last()}}{{/deprecatedMembers}} have been deprecated")
            {{scope}} init({{#members}}{{parameter}}: {{type}}{{#default}} = {{.}}{{/default}}{{^last()}}, {{/last()}}{{/members}}) {
    {{#members}}
                self.{{variable}} = {{variable}}
    {{/members}}
            }
    {{/empty(deprecatedMembers)}}
    {{#isResponse}}

            {{scope}} init(from decoder: Decoder) throws {
    {{#first(awsShapeMembers)}}
                let response = decoder.userInfo[.awsResponse] as? AWSResponse
    {{/first(awsShapeMembers)}}
                let container = try decoder.container(keyedBy: CodingKeys.self)
    {{#members}}
    {{#inBody}}            self.{{variable}} = try container.decode({{type}}.self, forKey: .{{variable}}){{/inBody}}
    {{#inHeader}}            self.{{variable}} = response?.headerValue("{{variable}}"){{#default}} ?? {{.}}{{/default}}{{/inHeader}}
    {{#isPayload}}            self.{{variable}} = request.body{{/isPayload}}
    {{/members}}
            }
    {{/isResponse}}
    {{! validate() function }}
    {{#first(validation)}}

            {{scope}} func validate(name: String) throws {
    {{#validation}}
    {{#shape}}
                try self.{{name}}{{^required}}?{{/required}}.validate(name: "\(name).{{name}}")
    {{/shape}}
    {{! validate array members }}
    {{#.member}}
                try self.{{name}}{{^required}}?{{/required}}.forEach {
    {{#shape}}
                    try $0.validate(name: "\(name).{{name}}[]")
    {{/shape}}
    {{#sorted(reqs)}}
                    try validate($0, name: "{{name}}[]", parent: name, {{.key}}: {{.value}})
    {{/sorted(reqs)}}
                }
    {{/.member}}
    {{! validate dictionary members }}
    {{#withDictionaryContexts(.)}}
                try self.{{name}}{{^required}}?{{/required}}.forEach {
    {{#.keyValidation}}
    {{#shape}}
                    try $0.key.validate(name: "\(name).{{name}}.key")
    {{/shape}}
    {{#sorted(reqs)}}
                    try validate($0.key, name: "{{name}}.key", parent: name, {{.key}}: {{.value}})
    {{/sorted(reqs)}}
    {{/.keyValidation}}
    {{! validate dictionary values }}
    {{#.valueValidation}}
    {{#shape}}
                    try $0.value.validate(name: "\(name).{{name}}[\"\($0.key)\"]")
    {{/shape}}
    {{#sorted(reqs)}}
                    try validate($0.value, name: "{{name}}[\"\($0.key)\"]", parent: name, {{.key}}: {{.value}})
    {{/sorted(reqs)}}
    {{/.valueValidation}}
                }
    {{/withDictionaryContexts(.)}}
    {{! validate min,max,pattern }}
    {{#sorted(reqs)}}
                try self.validate(self.{{name}}, name: "{{name}}", parent: name, {{.key}}: {{.value}})
    {{/sorted(reqs)}}
    {{/validation}}
            }
    {{/first(validation)}}
    {{! CodingKeys enum }}
    {{^empty(members)}}

    {{#empty(codingKeys)}}
            private enum CodingKeys: CodingKey {}
    {{/empty(codingKeys)}}
    {{^empty(codingKeys)}}
            private enum CodingKeys: String, CodingKey {
    {{#codingKeys}}
                case {{variable}} = "{{rawValue}}"
    {{/codingKeys}}
            }
    {{/empty(codingKeys)}}
    {{/empty(members)}}
        }

    """#
}
