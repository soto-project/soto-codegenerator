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

public struct IdempotencyTokenTrait: EmptyTrait {
    public static var staticName = "smithy.api#idempotencyToken"
    public static var selector: Selector = TargetSelector(ShapeSelector<StringShape>())
    public init() {}
}

public struct IdempotentTrait: EmptyTrait {
    public static var staticName = "smithy.api#idempotent"
    public static var selector: Selector = ShapeSelector<OperationShape>()
    public init() {}
}

public struct ReadonlyTrait: EmptyTrait {
    public static var staticName = "smithy.api#readonly"
    public static var selector: Selector = ShapeSelector<OperationShape>()
    public init() {}
}

public struct RetryableTrait: StaticTrait {
    public static var staticName = "smithy.api#retryable"
    public static var selector: Selector = AndSelector(ShapeSelector<StructureShape>(), TraitSelector<ErrorTrait>())
    public let throttling: Bool?
}

public struct PaginatedTrait: StaticTrait {
    public static var staticName = "smithy.api#paginated"
    public static var selector: Selector = OrSelector(ShapeSelector<OperationShape>(), ShapeSelector<ServiceShape>())
    public let inputToken: String?
    public let outputToken: String?
    public let items: String?
    public let pageSize: String?
}

public struct HttpChecksumRequiredTrait: EmptyTrait {
    public static var staticName = "smithy.api#httpChecksumRequired"
    public static var selector: Selector = ShapeSelector<OperationShape>()
    public init() {}
}
