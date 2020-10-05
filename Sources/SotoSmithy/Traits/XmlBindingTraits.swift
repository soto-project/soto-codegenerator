//===----------------------------------------------------------------------===//
//
// This source file is part of the Soto for AWS open source project
//
// Copyright (c) 2020 the Soto project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Soto project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

public struct XmlAttributeTrait: EmptyTrait {
    public static let name = "smithy.api#xmlAttribute"
    public init() { }
}

public struct XmlFlattenedTrait: EmptyTrait {
    public static let name = "smithy.api#xmlFlattened"
    public init() { }
}

public struct XmlNameTrait: StringTrait {
    public static let name = "smithy.api#xmlName"
    public var value: String
    public init(value: String) {
        self.value = value
    }
}

public struct XmlNamespaceTrait: Trait {
    public static let name = "smithy.api#xmlNamespace"
    public let uri: String
    public let prefix: String?
}
