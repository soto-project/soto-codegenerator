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
    static var possibleTraits: [String: Trait.Type] = [:]

    private let traits: [ObjectIdentifier: Trait]
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var traits: [ObjectIdentifier: Trait] = [:]
        for key in container.allKeys {
            guard let traitType = Self.possibleTraits[key.stringValue] else {
                throw DecodingError.dataCorruptedError(forKey: key, in: container, debugDescription: "Unrecognised trait type")
            }
            let trait = try traitType.decode(from: decoder)
            traits[ObjectIdentifier(traitType)] = trait
        }
        self.traits = traits
    }
    
    public func encode(to encoder: Encoder) throws {
        fatalError("TraitList.encode Not implemented")
    }
    
    public func trait<T: Trait>(type: T.Type) -> T? {
        return traits[ObjectIdentifier(T.self)].map { $0 as! T }
    }
    
    public static func registerTraitTypes(_ traitTypes: [Trait.Type]) {
        for trait in traitTypes {
            possibleTraits[trait.name] = trait
        }
    }
    
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
