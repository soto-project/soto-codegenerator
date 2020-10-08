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

public struct Model: Decodable {
    static let smithy = Smithy()
    let version: String
    let metadata: [String: MetadataValue]?
    var shapes: [ShapeId: AnyShape]
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try container.decode(String.self, forKey: .version)
        self.metadata = try container.decodeIfPresent([String: MetadataValue].self, forKey: .metadata)
        var shapes = Self.smithy.preludeShapes.mapValues { AnyShape(value: $0) }
        if let decodedShapes = try container.decodeIfPresent([String: AnyShape].self, forKey: .shapes) {
            for shape in decodedShapes {
                shapes[ShapeId(rawValue:shape.key)] = shape.value
            }
        }
        self.shapes = shapes
    }
    
    public func shape(for identifier: ShapeId) -> Shape? {
        if let member = identifier.member {
            if let shape = shapes[identifier.rootShapeId]?.shapeSelf {
                switch shape {
                case let structure as StructureShape:
                    return structure.members[member]
                default:
                    break
                }
            }
            return nil
        } else {
            return shapes[identifier]?.shapeSelf
        }
    }

    public func shapes<S: Shape>(of shapeType: S.Type) -> [ShapeId: S] {
        return shapes.compactMapValues { $0.value as? S }
    }

    public func validate() throws {
        try shapes.forEach { try $0.value.validate(using: self) }
    }

    public mutating func add(trait: Trait, to identifier: ShapeId) throws {
        if let member = identifier.member {
            guard try shapes[identifier.rootShapeId]?.add(trait: trait, to: member) != nil else {
                throw Smithy.ShapeDoesNotExistError(id: identifier)
            }
        } else {
            guard shapes[identifier]?.add(trait: trait) != nil else {
                throw Smithy.ShapeDoesNotExistError(id: identifier)
            }
        }
    }

    public mutating func remove(trait: StaticTrait.Type, from identifier: ShapeId) throws {
        if let member = identifier.member {
            guard try shapes[identifier.rootShapeId]?.remove(trait: trait, from: member) != nil else {
                throw Smithy.ShapeDoesNotExistError(id: identifier)
            }
        } else {
            guard shapes[identifier]?.remove(trait: trait) != nil else {
                throw Smithy.ShapeDoesNotExistError(id: identifier)
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case version = "smithy"
        case metadata
        case shapes
    }
}
