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

public struct StreamingTrait: EmptyTrait {
    public static let name = "smithy.api#streaming"
    public static let selector: Selector = OrSelector(ShapeSelector<BlobShape>(), ShapeSelector<UnionShape>())
    public init() {}
}

public struct RequiresLengthTrait: EmptyTrait {
    public static let name = "smithy.api#requiresLength"
    public static let selector: Selector = TraitSelector<StreamingTrait>()
    public init() {}
}

public struct EventHeaderTrait: EmptyTrait {
    public static let name = "smithy.api#eventHeader"
    public static let selector: Selector = TargetSelector(OrSelector(
        ShapeSelector<BooleanShape>(),
        ShapeSelector<ByteShape>(),
        ShapeSelector<ShortShape>(),
        ShapeSelector<IntegerShape>(),
        ShapeSelector<LongShape>(),
        ShapeSelector<BlobShape>(),
        ShapeSelector<StringShape>(),
        ShapeSelector<TimestampShape>()
    ))
    public init() {}
}

public struct EventPayloadTrait: EmptyTrait {
    public static let name = "smithy.api#eventPayload"
    public static let selector: Selector = TargetSelector(OrSelector(
        ShapeSelector<BlobShape>(),
        ShapeSelector<StringShape>(),
        ShapeSelector<StructureShape>(),
        ShapeSelector<UnionShape>()
    ))
    public init() {}
}
