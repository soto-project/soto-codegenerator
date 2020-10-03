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

