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

/// List of traits.
///
public struct TraitList: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var traits: [String: StaticTrait] = [:]
        for key in container.allKeys {
            guard let traitType = Self.possibleTraits[key.stringValue] else {
                throw DecodingError.dataCorruptedError(forKey: key, in: container, debugDescription: "Unrecognised trait type")
            }
            let trait = try traitType.decode(from: decoder, key: key)
            traits[traitType.staticName] = trait
        }
        self.traits = traits
    }

    public func encode(to encoder: Encoder) throws {
        fatalError("TraitList.encode Not implemented")
    }

    public func trait<T: StaticTrait>(type: T.Type) -> T? {
        return traits[T.staticName].map { $0 as! T }
    }

    public mutating func add(trait: Trait) {
        traits[trait.name] = trait
    }

    public mutating func remove(trait: StaticTrait.Type) {
        traits[trait.staticName] = nil
    }

    static func registerTraitTypes(_ traitTypes: [StaticTrait.Type]) {
        for trait in traitTypes {
            possibleTraits[trait.staticName] = trait
        }
    }

    func validate(using model: Model, shape: Shape) throws {
        try traits.forEach {
            try $0.value.validate(using: model, shape: shape)
        }
    }

    init(traits traitsArray: [Trait]) {
        var traits: [String: Trait] = [:]
        traitsArray.forEach {
            traits[$0.name] = $0
        }
        self.traits = traits
    }

    private static var possibleTraits: [String: StaticTrait.Type] = [:]
    private var traits: [String: Trait]

    private struct CodingKeys: CodingKey {
        var stringValue: String
        var intValue: Int? { return nil }

        init?(stringValue: String) {
            self.stringValue = stringValue
        }
        init?(intValue: Int) {
            return nil
        }
    }
}

extension TraitList: ExpressibleByArrayLiteral {
    public typealias ArrayLiteralElement = Trait
    public init(arrayLiteral elements: Trait...) {
        self.init(traits: elements)
    }
}

extension TraitList: Sequence {
    public typealias Element = Trait
    public typealias Iterator = Dictionary<String, Trait>.Values.Iterator

    public func makeIterator() -> Iterator {
        return traits.values.makeIterator()
    }
}
