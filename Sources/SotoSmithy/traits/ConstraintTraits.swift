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

struct EnumTrait: ListTrait {
    static let name = "smithy.api#enum"
    struct EnumDefinition: Codable {
        let value: String
        let name: String
        let documentation: String
        let tags: [String]
        let deprecated: Bool
    }
    typealias Element = EnumDefinition
    let list: [EnumDefinition]
}

struct IdRefTrait: Trait {
    static let name = "smithy.api#idRef"
    let failWhenMissing: Bool
    let selector: String
    let errorMessage: String
}

struct LengthTrait: Trait {
    static let name = "smithy.api#length"
    let min: Int
    let max: Int
}

struct PatternTrait: StringTrait {
    static let name = "smithy.api#pattern"
    let string: String
}

struct PrivateTrait: EmptyTrait {
    static let name = "smithy.api#private"
}

struct RangeTrait: Trait {
    static let name = "smithy.api#range"
    let min: Double
    let max: Double
}

struct RequiredTrait: EmptyTrait {
    static let name = "smithy.api#required"
}

struct UniqueItemsTrait: EmptyTrait {
    static let name = "smithy.api#uniqueItems"
}
