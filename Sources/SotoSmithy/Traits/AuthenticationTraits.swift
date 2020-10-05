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

public struct AuthDefinitionTrait: EmptyTrait {
    public static let name = "smithy.api#authDefinition"
    public init() {}
}

public struct HttpBasicAuthTrait: EmptyTrait {
    public static let name = "smithy.api#httpBasicAuth"
    public static let selector: Selector = ShapeSelector<ServiceShape>()
    public init() {}
}

public struct HttpDigestAuthTrait: EmptyTrait {
    public static let name = "smithy.api#httpDigestAuth"
    public static let selector: Selector = ShapeSelector<ServiceShape>()
    public init() {}
}

public struct HttpBearerAuthTrait: EmptyTrait {
    public static let name = "smithy.api#httpBearerAuth"
    public static let selector: Selector = ShapeSelector<ServiceShape>()
    public init() {}
}

public struct HttpApiKeyAuthTrait: Trait {
    public static let name = "smithy.api#httpApiKeyAuth"
    public static let selector: Selector = ShapeSelector<ServiceShape>()
    public let name: String
    public let `in`: String
}

public struct OptionalAuthTrait: EmptyTrait {
    public static let name = "smithy.api#optionalAuth"
    public static let selector: Selector = ShapeSelector<OperationShape>()
    public init() {}
}

public struct AuthTrait: SingleValueTrait {
    public static let name = "smithy.api#auth"
    public static let selector: Selector = OrSelector(ShapeSelector<ServiceShape>(), ShapeSelector<OperationShape>())
    public typealias Value = [String]
    public let value: Value
    public init(value: Value) {
        self.value = value
    }
}
