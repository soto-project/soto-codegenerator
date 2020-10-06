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

public struct MemberShape: Shape {
    public let target: ShapeId
    public var traits: TraitList?

    public func validate(using model: Model) throws {
        guard let shape = model.shape(for: target) else { throw Smithy.ValidationError(reason: "Member references non-existent shape \(target)")}
        guard !(shape is OperationShape),
              !(shape is ResourceShape),
              !(shape is ServiceShape) else {
            throw Smithy.ValidationError(reason: "Member references illegal shape \(target)")
        }
        try traits?.validate(using: model, shape: self)
   }
}

public struct ListShape: Shape {
    public static let type = "list"
    public var traits: TraitList?
    public let member: MemberShape
    public func validate(using model: Model) throws {
        try member.validate(using: model)
        try traits?.validate(using: model, shape: self)
    }
}

public struct SetShape: Shape {
    public static let type = "set"
    public var traits: TraitList?
    public let member: MemberShape
    public func validate(using model: Model) throws {
        try member.validate(using: model)
        try traits?.validate(using: model, shape: self)
    }
}

public struct MapShape: Shape {
    public static let type = "map"
    public var traits: TraitList?
    public let key: MemberShape
    public let value: MemberShape
    public func validate(using model: Model) throws {
        try key.validate(using: model)
        try value.validate(using: model)
        try traits?.validate(using: model, shape: self)
    }
}

public struct StructureShape: Shape {
    public static let type = "structure"
    public var traits: TraitList?
    public var members: [String: MemberShape]
    public func validate(using model: Model) throws {
        try members.forEach { try $0.value.validate(using: model) }
        try traits?.validate(using: model, shape: self)
    }
    public mutating func add(trait: Trait, to member: String) {
        members[member]?.add(trait: trait)
    }
}

public struct UnionShape: Shape {
    public static let type = "union"
    public var traits: TraitList?
    public var members: [String: MemberShape]
    public func validate(using model: Model) throws {
        try members.forEach { try $0.value.validate(using: model) }
        try traits?.validate(using: model, shape: self)
    }
    public mutating func add(trait: Trait, to member: String) {
        members[member]?.add(trait: trait)
    }
}
