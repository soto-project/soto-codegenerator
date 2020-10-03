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

public struct EnumTrait: ListTrait {
    public static let name = "smithy.api#enum"
    public struct EnumDefinition: Codable {
        public let value: String
        public let name: String?
        public let documentation: String?
        public let tags: [String]?
        public let deprecated: Bool?
    }
    public typealias Element = EnumDefinition
    public let list: [EnumDefinition]
    public init(list: [EnumDefinition]) {
        self.list = list
    }
}

public struct IdRefTrait: Trait {
    public static let name = "smithy.api#idRef"
    public let failWhenMissing: Bool?
    public let selector: String?
    public let errorMessage: String?
}

public struct LengthTrait: Trait {
    public static let name = "smithy.api#length"
    public let min: Int?
    public let max: Int?
}

public struct PatternTrait: StringTrait {
    public init(string: String) {
        self.string = string
    }
    public static let name = "smithy.api#pattern"
    public let string: String
}

public struct PrivateTrait: EmptyTrait {
    public static let name = "smithy.api#private"
    public init() {}
}

public struct RangeTrait: Trait {
    public static let name = "smithy.api#range"
    public let min: Double?
    public let max: Double?
}

public struct RequiredTrait: EmptyTrait {
    public static let name = "smithy.api#required"
    public init() {}
}

public struct UniqueItemsTrait: EmptyTrait {
    public static let name = "smithy.api#uniqueItems"
    public init() {}
}
