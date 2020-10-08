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
    public static let staticName = "smithy.api#noReplace"
    public static var selector: Selector = ShapeSelector<ResourceShape>()
    public init() {}
}

public struct ReferencesTrait: SingleValueTrait {
    public static let staticName = "smithy.api#references"
    public static var selector: Selector = OrSelector(ShapeSelector<StructureShape>(), ShapeSelector<StringShape>())
    public struct Reference: Codable {
        public let service: ShapeId?
        public let resource: ShapeId
        public let ids: [String: String]?
        public let rel: String?
    }
    public typealias Value = [Reference]
    public let value: Value
    public init(value: Value) {
        self.value = value
    }
}

public struct ResourceIdentifierTrait: StringTrait {
    public static let staticName = "smithy.api#resourceIdentifier"
    public static var selector: Selector = AndSelector(
        ShapeSelector<MemberShape>(),
        TraitSelector<RequiredTrait>(),
        TargetSelector(ShapeSelector<StringShape>())
    )
    public var value: String
    public init(value: String) {
        self.value = value
    }
}
