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
    public static var name = "smithy.api#idempotencyToken"
    public init() {}
}

public struct IdempotentTrait: EmptyTrait {
    public static var name = "smithy.api#idempotent"
    public init() {}
}

public struct ReadonlyTrait: EmptyTrait {
    public static var name = "smithy.api#readonly"
    public init() {}
}

public struct RetryableTrait: Trait {
    public static var name = "smithy.api#retryable"
    public let throttling: Bool
}

public struct PaginatedTrait: Trait {
    public static var name = "smithy.api#paginated"
    public let inputToken: String?
    public let outputToken: String?
    public let items: String?
    public let pageSize: String?
}

public struct HttpChecksumRequiredTrait: EmptyTrait {
    public static var name = "smithy.api#httpChecksumRequired"
    public init() {}
}
