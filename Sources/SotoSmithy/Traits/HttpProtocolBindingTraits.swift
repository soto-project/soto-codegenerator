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

public struct HttpTrait: Trait {
    public static let name = "smithy.api#http"
    public let method: String
    public let uri: String
    public let code: Int?
}

public struct HttpErrorTrait: SingleValueTrait {
    public static let name = "smithy.api#httpError"
    public typealias Value = Int
    public var value: Int
    public init(value: Int) {
        self.value = value
    }
}

public struct HttpHeaderTrait: StringTrait {
    public static let name = "smithy.api#httpHeader"
    public var value: String
    public init(value: String) {
        self.value = value
    }
}

public struct HttpLabelTrait: EmptyTrait {
    public static let name = "smithy.api#httpLabel"
    public init() { }
}

public struct HttpPayloadTrait: EmptyTrait {
    public static let name = "smithy.api#httpPayload"
    public init() { }
}

public struct HttpPrefixHeadersTrait: StringTrait {
    public static let name = "smithy.api#httpPrefixHeaders"
    public var value: String
    public init(value: String) {
        self.value = value
    }
}

public struct HttpQueryTrait: StringTrait {
    public static let name = "smithy.api#httpQuery"
    public var value: String
    public init(value: String) {
        self.value = value
    }
}

public struct HttpResponseCodeTrait: EmptyTrait {
    public static let name = "smithy.api#httpResponseCode"
    public init() { }
}

public struct HttpCorsTrait: Trait {
    public static let name = "smithy.api#cors"
    public let origin: String?
    public let maxAge: Int?
    public let additionalAllowedHeaders: [String]?
    public let additionalExposedHeaders: [String]?
}
