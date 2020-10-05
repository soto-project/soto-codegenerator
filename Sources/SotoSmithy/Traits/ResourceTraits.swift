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

public struct NoReplaceTrait: EmptyTrait {
    public static let name = "smithy.api#noReplace"
    public init() {}
}

public struct ReferencesTrait: ListTrait {
    public static let name = "smithy.api#references"
    public struct Reference: Codable {
        public let service: ShapeId?
        public let resource: ShapeId
        public let ids: [String: String]?
        public let rel: String
    }
    public typealias Element = Reference
    public let list: [Element]
    public init(list: [Element]) {
        self.list = list
    }
}

public struct ResourceIdentifierTrait: StringTrait {
    public static let name = "smithy.api#resourceIdentifier"
    public var string: String
    public init(string: String) {
        self.string = string
    }
}
