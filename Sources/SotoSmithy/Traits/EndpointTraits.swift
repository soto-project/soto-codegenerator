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

public struct EndpointTrait: StaticTrait {
    public static let staticName = "smithy.api#endpoint"
    public static let selector: Selector = ShapeSelector<OperationShape>()
    public let hostPrefix: String
}

public struct HostLabelTrait: EmptyTrait {
    public static let staticName = "smithy.api#hostLabel"
    public static let selector: Selector = AndSelector(TraitSelector<RequiredTrait>(), TargetSelector(ShapeSelector<StringShape>()))
    public init() { }
}
