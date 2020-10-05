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

public struct TraitList: Codable {
    

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var traits: [String: Trait] = [:]
        for key in container.allKeys {
            guard let traitType = Self.possibleTraits[key.stringValue] else {
                throw DecodingError.dataCorruptedError(forKey: key, in: container, debugDescription: "Unrecognised trait type")
            }
            let trait = try traitType.decode(from: decoder)
            traits[traitType.name] = trait
        }
        self.traits = traits
    }
    
    public func encode(to encoder: Encoder) throws {
        fatalError("TraitList.encode Not implemented")
    }
    
    public func trait<T: Trait>(type: T.Type) -> T? {
        return traits[T.name].map { $0 as! T }
    }
    
    static func registerTraitTypes(_ traitTypes: [Trait.Type]) {
        for trait in traitTypes {
            possibleTraits[trait.name] = trait
        }
    }
    
    private static var possibleTraits: [String: Trait.Type] = [:]
    private let traits: [String: Trait]

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
        var traits: [String: Trait] = [:]
        elements.forEach {
            traits[type(of: $0).name] = $0
        }
        self.traits = traits
    }
}
