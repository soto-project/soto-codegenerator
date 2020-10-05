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
    public init(string: String) {
        self.string = string
    }
    public static let name = "smithy.api#documentation"
    public let string: String
}

public struct ExamplesTrait: ListTrait {
    public static let name = "smithy.api#examples"
    public struct Example: Codable {
        public let title: String
        public let documentation: String?
        public let input: String
        public let output: String
    }
    public typealias Element = Example
    public let list: [Element]
    public init(list: [Element]) {
        self.list = list
    }
}

public struct ExternalDocumentationTrait: MapTrait {
    public static let name = "smithy.api#externalDocumentation"
    public typealias Key = String
    public typealias Value = String
    public let map: [Key: Value]
    public init(map: [Key: Value]) {
        self.map = map
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
    public var string: String
    public init(string: String) {
        self.string = string
    }
}

public struct TagsTrait: ListTrait {
    public static let name = "smithy.api#tags"
    public typealias Element = String
    public let list: [Element]
    public init(list: [Element]) {
        self.list = list
    }
}

public struct TitleTrait: StringTrait {
    public static let name = "smithy.api#title"
    public var string: String
    public init(string: String) {
        self.string = string
    }
}

public struct UnstableTrait: EmptyTrait {
    public static let name = "smithy.api#unstable"
    public init() {}
}
