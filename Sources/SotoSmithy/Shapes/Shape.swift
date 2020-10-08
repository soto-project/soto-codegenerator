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

public protocol Shape: Codable {
    static var type: String { get }
    var traits: TraitList? { get set }
    var shapeSelf: Shape { get }
    func validate(using model: Model) throws
    mutating func add(trait: Trait, to member: String) throws
    mutating func remove(trait: StaticTrait.Type, from member: String) throws
}

extension Shape {
    public static var type: String { return "_undefined_" }
    public var shapeSelf: Shape { return self }

    public func validate(using model: Model) throws {
        try traits?.validate(using: model, shape: self)
    }

    public func trait<T: StaticTrait>(type: T.Type) -> T? {
        return traits?.trait(type: T.self)
    }

    public mutating func add(trait: Trait) {
        if var traits = self.traits {
            traits.add(trait: trait)
        } else {
            self.traits = TraitList(traits: [trait])
        }
    }

    public mutating func remove(trait: StaticTrait.Type) {
        self.traits?.remove(trait: trait)
    }

    public mutating func add(trait: Trait, to member: String) throws {
        throw Smithy.MemberDoesNotExistError(name: member)
    }

    public mutating func remove(trait: StaticTrait.Type, from member: String) throws {
        throw Smithy.MemberDoesNotExistError(name: member)
    }
}

public struct AnyShape: Shape {
    static var possibleShapes: [String: Shape.Type] = [:]
    public var value: Shape
    public var traits: TraitList? {
        get { return shapeSelf.traits }
        set { value.traits = newValue }
    }
    public var shapeSelf: Shape { return value }
    
    init(value: Shape) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        guard let shapeType = Self.possibleShapes[type] else {
            throw DecodingError.dataCorruptedError(forKey: CodingKeys.type, in: container, debugDescription: "Unrecognised shape type")
        }
        self.value = try shapeType.init(from: decoder)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.type, forKey: .type)
        try value.encode(to: encoder)
    }
    
    public func validate(using model: Model) throws {
        try self.value.validate(using: model)
    }
    
    public mutating func add(trait: Trait, to member: String) throws {
        try self.value.add(trait: trait, to: member)
    }

    public mutating func remove(trait: StaticTrait.Type, from member: String) throws {
        try self.value.remove(trait: trait, from: member)
    }

    public static func registerShapeTypes(_ shapes: [Shape.Type]) {
        for shape in shapes {
            possibleShapes[shape.type] = shape
        }
    }

    private enum CodingKeys: CodingKey {
        case type
    }
}

