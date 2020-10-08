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

public protocol Trait: Decodable {
    static var selector: Selector { get }
    func validate(using model: Model, shape: Shape) throws
    var name: String { get }
}

extension Trait {
    static func decode<Key: CodingKey>(from decoder: Decoder, key: Key) throws -> Self {
        let container = try decoder.container(keyedBy: Key.self)
        let value = try container.decode(Self.self, forKey: key)
        return value
    }
    public static var selector: Selector { return AllSelector() }
    public func validate(using model: Model, shape: Shape) throws {
        guard Self.selector.select(using: model, shape: shape) else {
            throw Smithy.ValidationError(reason: "Trait \(name) cannot be applied to \(type(of: shape).type)")
        }
    }
}

public protocol StaticTrait: Trait {
    static var staticName: String { get }
}

extension StaticTrait {
    public var name: String { return Self.staticName }
}

public protocol EmptyTrait: StaticTrait {
    init()
}

extension EmptyTrait {
    public init(from decoder: Decoder) throws { self.init() }
}

public protocol SingleValueTrait: StaticTrait {
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
