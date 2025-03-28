//===----------------------------------------------------------------------===//
//
// This source file is part of the Soto for AWS open source project
//
// Copyright (c) 2017-2020 the Soto project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Soto project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import SotoSmithy

/// Protocol for patching a Smithy shape.
protocol ShapePatch {
    /// Patch Smithy Shape.
    /// - Parameter shape: Original Shape
    /// - Returns: Patched shape, nil means don't patch the shape
    func patch(shape: Shape) throws -> Shape?
}

struct ShapeTypePatch: ShapePatch {
    let shape: Shape
    func patch(shape: Shape) -> Shape? {
        self.shape
    }
}

/// Patch using a closure to provide a new shape
struct EditShapePatch<S: Shape>: ShapePatch {
    let edit: (S) -> (Shape)

    func patch(shape: Shape) -> Shape? {
        guard let shape = shape as? S else { return nil }
        return self.edit(shape)
    }
}

/// Add member to collection shape patch
struct AddShapeMemberPatch<S: CollectionShape>: ShapePatch {
    let name: String
    let shapeId: ShapeId
    let traits: TraitList?

    func patch(shape: Shape) throws -> Shape? {
        guard let shape = shape as? S else { return nil }
        guard shape.members?[self.name] == nil else {
            throw PatchError(message: "Shape already has member named \(self.name)")
        }
        let memberShape = MemberShape(target: self.shapeId, traits: self.traits)
        if var members = shape.members {
            members[self.name] = memberShape
            shape.members = members
        } else {
            shape.members = [self.name: memberShape]
        }
        return shape
    }
}

extension AddShapeMemberPatch where S == EnumShape {
    /// Specialization of init for EnumShapes which just requires the new enum value
    init(name: String) {
        self.init(name: name, shapeId: "smithy.api#Unit", traits: [EnumValueTrait(value: .string(name))])
    }
}

/// Remove member from shape patch
struct RemoveShapeMemberPatch<S: CollectionShape>: ShapePatch {
    let name: String

    func patch(shape: Shape) throws -> Shape? {
        guard let shape = shape as? S else { return nil }
        guard shape.members?[self.name] != nil else {
            throw PatchError(message: "Shape does not have member named \(self.name)")
        }
        shape.members?.removeValue(forKey: self.name)
        return shape
    }
}

/// Create new shape
struct CreateShapePatch: ShapePatch {
    let shape: Shape
    let patch: ShapePatch?

    init(shape: Shape, patch: ShapePatch? = nil) {
        self.shape = shape
        self.patch = patch
    }

    func create() throws -> Shape? {
        try self.patch(shape: self.shape)
    }

    func patch(shape: Shape) throws -> Shape? {
        try self.patch?.patch(shape: shape) ?? shape
    }
}

/// Add a trait to a shape
struct AddTraitPatch: ShapePatch {
    let trait: Trait
    func patch(shape: Shape) -> Shape? {
        shape.add(trait: self.trait)
        return nil
    }
}

/// Remove a trait from a shape
struct RemoveTraitPatch: ShapePatch {
    let trait: StaticTrait.Type
    func patch(shape: Shape) throws -> Shape? {
        guard shape.trait(named: self.trait.staticName) != nil else {
            throw PatchError(message: "Does not have trait \(self.trait.staticName)")
        }
        shape.removeTrait(named: self.trait.staticName)
        return nil
    }
}

/// Edit trait attached to shape
struct EditTraitPatch<T: StaticTrait>: ShapePatch {
    let edit: (T) -> (T)
    func patch(shape: Shape) throws -> Shape? {
        guard let trait = shape.trait(type: T.self) else {
            throw PatchError(message: "Does not have trait \(T.staticName)")
        }
        let newTrait = self.edit(trait)
        shape.remove(trait: T.self)
        shape.add(trait: newTrait)
        return nil
    }
}

/// Edit EnumTrait attached to a shape
struct EditEnumTraitPatch: ShapePatch {
    let add: [EnumTrait.EnumDefinition]
    let remove: [String]

    init(add: [EnumTrait.EnumDefinition] = [], remove: [String] = []) {
        self.add = add
        self.remove = remove
    }

    func patch(shape: Shape) throws -> Shape? {
        guard let enumTrait = shape.trait(type: EnumTrait.self) else {
            throw PatchError(message: "Does not have Enum trait")
        }
        var enums = enumTrait.value
        // remove values
        for value in self.remove {
            guard enums.first(where: { $0.value == value }) != nil else {
                throw PatchError(message: "Trying to remove enum \"\(value)\" that does not exist")
            }
        }
        enums.removeAll { remove.contains($0.value) }
        // add values
        for value in self.add {
            guard enums.first(where: { $0.value == value.value }) == nil else {
                throw PatchError(message: "Trying to add enum \"\(value.value)\" that already exists")
            }
        }
        enums += self.add
        let newEnumTrait = EnumTrait(value: enums)
        shape.remove(trait: EnumTrait.self)
        shape.add(trait: newEnumTrait)
        return nil
    }
}

/// Apply multiple shape patches to a shape
struct MultiplePatch: ShapePatch {
    let patches: [ShapePatch]

    init(_ patches: [ShapePatch]) {
        self.patches = patches
    }

    init(_ patches: ShapePatch...) {
        self.init(patches)
    }

    func patch(shape: Shape) throws -> Shape? {
        var shape = shape
        for patch in self.patches {
            if let newShape = try patch.patch(shape: shape) {
                shape = newShape
            }
        }
        return shape
    }
}

struct PatchError: Error {
    public let message: String
}
