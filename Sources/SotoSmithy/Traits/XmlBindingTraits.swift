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
    public static let staticName = "smithy.api#xmlAttribute"
    public static let selector: Selector = TargetSelector(OrSelector(
        ShapeSelector<BooleanShape>(),
        NumberSelector(),
        ShapeSelector<StringShape>(),
        ShapeSelector<TimestampShape>()
    ))
    public init() { }
}

public struct XmlFlattenedTrait: EmptyTrait {
    public static let staticName = "smithy.api#xmlFlattened"
    public static let selector: Selector = TargetSelector(OrSelector(
        ShapeSelector<ListShape>(),
        ShapeSelector<SetShape>(),
        ShapeSelector<MapShape>()
    ))
    public init() { }
}

public struct XmlNameTrait: StringTrait {
    public static let staticName = "smithy.api#xmlName"
    public static let selector: Selector = OrSelector(
        ShapeSelector<StructureShape>(),
        ShapeSelector<UnionShape>(),
        ShapeSelector<MemberShape>()
    )
    public var value: String
    public init(value: String) {
        self.value = value
    }
}

public struct XmlNamespaceTrait: StaticTrait {
    public static let staticName = "smithy.api#xmlNamespace"
    public let uri: String
    public let prefix: String?
}
