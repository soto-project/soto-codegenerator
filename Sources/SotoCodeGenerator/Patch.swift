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

protocol ShapePatch {
    func patch(shape: Shape) -> Shape?
}

struct ShapeTypePatch: ShapePatch {
    let shape: Shape
    func patch(shape: Shape) -> Shape? {
        return self.shape
    }
}

struct EditShapePatch<S: Shape>: ShapePatch {
    let edit: (S) -> (Shape)

    func patch(shape: Shape) -> Shape? {
        guard let shape = shape as? S else { return nil }
        return self.edit(shape)
    }
}

struct AddTraitPatch: ShapePatch {
    let trait: Trait
    func patch(shape: Shape) -> Shape? {
        shape.add(trait: self.trait)
        return nil
    }
}

struct RemoveTraitPatch: ShapePatch {
    let trait: StaticTrait.Type
    func patch(shape: Shape) -> Shape? {
        shape.removeTrait(named: self.trait.staticName)
        return nil
    }
}

struct EditTraitPatch<T: StaticTrait>: ShapePatch {
    let edit: (T) -> (T)
    func patch(shape: Shape) -> Shape? {
        guard let trait = shape.trait(type: T.self) else { return nil }
        let newTrait = self.edit(trait)
        shape.remove(trait: T.self)
        shape.add(trait: newTrait)
        return nil
    }
}

struct EditEnumPatch: ShapePatch {
    let add: [EnumTrait.EnumDefinition]
    let remove: [String]

    init(add: [EnumTrait.EnumDefinition] = [], remove: [String] = []) {
        self.add = add
        self.remove = remove
    }

    func patch(shape: Shape) -> Shape? {
        guard let enumTrait = shape.trait(type: EnumTrait.self) else { return nil }
        var enums = enumTrait.value
        enums.removeAll { remove.contains($0.value) }
        enums += self.add
        let newEnumTrait = EnumTrait(value: enums)
        shape.remove(trait: EnumTrait.self)
        shape.add(trait: newEnumTrait)
        return nil
    }
}

struct MultiplePatch: ShapePatch {
    let patches: [ShapePatch]

    init(_ patches: [ShapePatch]) {
        self.patches = patches
    }

    func patch(shape: Shape) -> Shape? {
        var shape = shape
        for patch in self.patches {
            if let newShape = patch.patch(shape: shape) {
                shape = newShape
            }
        }
        return shape
    }
}
