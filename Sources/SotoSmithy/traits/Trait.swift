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

protocol Trait: Codable {
    static var name: String { get }
}

protocol EmptyTrait: Trait {
    init()
}

extension EmptyTrait {
    init(from decoder: Decoder) throws { self.init() }
}
    
protocol StringTrait: Trait {
    var string: String { get }
    init(string: String)
}

extension StringTrait {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        self.init(string: string)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(string)
    }
}

protocol ListTrait: Trait {
    associatedtype Element: Codable
    var list: [Element] { get }
    init(list: [Element])
}

extension ListTrait {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let list = try container.decode([Element] .self)
        self.init(list: list)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(list)
    }
}

