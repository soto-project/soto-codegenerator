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
    func validate(using model: Model, shape: Shape) throws
}

extension Trait {
    static func decode(from decoder: Decoder) throws -> Self {
        let container = try decoder.container(keyedBy: TraitCodingKeys.self)
        let value = try container.decode(Self.self, forKey: TraitCodingKeys(stringValue: name)!)
        return value
    }

    public func validate(using model: Model, shape: Shape) throws { }
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

public protocol SingleValueTrait: Trait {
    associatedtype Value: Codable
    var value: Value { get }
    init(value: Value)
}

extension SingleValueTrait {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(Value.self)
        self.init(value: value)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

public protocol StringTrait: SingleValueTrait where Value == String {
}
