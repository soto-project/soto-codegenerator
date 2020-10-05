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

public protocol Trait: Codable {
    static var name: String { get }
}

extension Trait {
    static func decode(from decoder: Decoder) throws -> Self {
        let container = try decoder.container(keyedBy: TraitCodingKeys.self)
        let value = try container.decode(Self.self, forKey: TraitCodingKeys(stringValue: name)!)
        return value
    }
}

private struct TraitCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int? { return nil }

    init?(stringValue: String) {
        self.stringValue = stringValue
    }
    init?(intValue: Int) {
        return nil
    }
}

public protocol EmptyTrait: Trait {
    init()
}

extension EmptyTrait {
    public init(from decoder: Decoder) throws { self.init() }
}
    
public protocol StringTrait: Trait {
    var string: String { get }
    init(string: String)
}

extension StringTrait {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        self.init(string: string)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(string)
    }
}

public protocol ListTrait: Trait {
    associatedtype Element: Codable
    var list: [Element] { get }
    init(list: [Element])
}

extension ListTrait {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let list = try container.decode([Element] .self)
        self.init(list: list)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(list)
    }
}

public protocol MapTrait: Trait {
    associatedtype Key: Codable, Hashable
    associatedtype Value: Codable
    var map: [Key: Value] { get }
    init(map: [Key: Value])
}

extension MapTrait {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let map = try container.decode([Key: Value] .self)
        self.init(map: map)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(map)
    }
}

