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

public struct DeprecatedTrait: Trait {
    public static let name = "smithy.api#deprecated"
    public let message: String?
    public let since: String?
}

public struct DocumentationTrait: StringTrait {
    public init(value: String) {
        self.value = value
    }
    public static let name = "smithy.api#documentation"
    public let value: String
}

public struct ExamplesTrait: SingleValueTrait {
    public static let name = "smithy.api#examples"
    public struct Example: Codable {
        public let title: String
        public let documentation: String?
        public let input: String
        public let output: String
    }
    public typealias Value = [Example]
    public let value: Value
    public init(value: Value) {
        self.value = value
    }
}

public struct ExternalDocumentationTrait: SingleValueTrait {
    public static let name = "smithy.api#externalDocumentation"
    public typealias Value = [String: String]
    public let value: Value
    public init(value: Value) {
        self.value = value
    }

}

public struct InternalTrait: EmptyTrait {
    public static let name = "smithy.api#internal"
    public init() {}
}

public struct SensitiveTrait: EmptyTrait {
    public static let name = "smithy.api#sensitive"
    public init() {}
}

public struct SinceTrait: StringTrait {
    public static let name = "smithy.api#since"
    public var value: String
    public init(value: String) {
        self.value = value
    }
}

public struct TagsTrait: SingleValueTrait {
    public static let name = "smithy.api#tags"
    public typealias Value = [String]
    public let value: Value
    public init(value: Value) {
        self.value = value
    }
}

public struct TitleTrait: StringTrait {
    public static let name = "smithy.api#title"
    public var value: String
    public init(value: String) {
        self.value = value
    }
}

public struct UnstableTrait: EmptyTrait {
    public static let name = "smithy.api#unstable"
    public init() {}
}
