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

public struct BoxTrait: EmptyTrait {
    public static let name = "smithy.api#box"
    public static let selector: Selector = OrTargetSelector(
        OrSelector(
            ShapeSelector<BooleanShape>(),
            ShapeSelector<ByteShape>(),
            ShapeSelector<ShortShape>(),
            ShapeSelector<IntegerShape>(),
            ShapeSelector<LongShape>(),
            ShapeSelector<FloatShape>(),
            ShapeSelector<DoubleShape>()
        )
    )
    public init() {}
}

public struct ErrorTrait: SingleValueTrait {
    public static let name = "smithy.api#error"
    public static let selector: Selector = ShapeSelector<StructureShape>()
    public enum ErrorType: String, Codable {
        case client
        case server
    }
    public typealias Value = ErrorType
    public let value: Value
    public init(value: Value) {
        self.value = value
    }
}

