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
    func patch(shape: Shape)
}

struct RemoteTraitPatch: ShapePatch {
    let trait: StaticTrait.Type
    func patch(shape: Shape) {
        shape.removeTrait(named: trait.staticName)
    }
}

struct EditEnumPatch: ShapePatch {
    var add: [EnumTrait.EnumDefinition] = []
    var remove: [String] = []
    
    func patch(shape: Shape) {
        guard let enumTrait = shape.trait(type: EnumTrait.self) else { return }
        var enums = enumTrait.value
        enums.removeAll { remove.contains($0.value) }
        enums += add
        let newEnumTrait = EnumTrait(value: enums)
        shape.remove(trait: EnumTrait.self)
        shape.add(trait: newEnumTrait)
    }
}

