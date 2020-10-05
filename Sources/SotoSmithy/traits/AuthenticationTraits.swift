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
    public init() {}
}

public struct HttpDigestAuthTrait: EmptyTrait {
    public static let name = "smithy.api#httpDigestAuth"
    public init() {}
}

public struct HttpBearerAuthTrait: EmptyTrait {
    public static let name = "smithy.api#httpBearerAuth"
    public init() {}
}

public struct HttpApiKeyAuthTrait: Trait {
    public static let name = "smithy.api#httpApiKeyAuth"
    public let name: String
    public let `in`: String
}

public struct OptionalAuthTrait: EmptyTrait {
    public static let name = "smithy.api#optionalAuth"
    public init() {}
}

public struct AuthTrait: ListTrait {
    public static let name = "smithy.api#auth"
    public typealias Element = String
    public let list: [Element]
    public init(list: [Element]) {
        self.list = list
    }
}
