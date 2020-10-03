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

struct MemberShape: Shape {
    let target: ShapeId
    
    func validate(using model: Model) throws {
        guard let shape = model.shape(for: target) else { throw Smithy.ValidationError(reason: "Member references non-existent shape \(target)")}
        guard !(shape is OperationShape),
              !(shape is ResourceShape),
              !(shape is ServiceShape) else {
            throw Smithy.ValidationError(reason: "Member references illegal shape \(target)")
        }
    }
}

struct ListShape: Shape {
    static let type = "list"
    let member: MemberShape
    func validate(using model: Model) throws {
        try member.validate(using: model)
    }
}

struct SetShape: Shape {
    static let type = "set"
    let member: MemberShape
    func validate(using model: Model) throws {
        try member.validate(using: model)
    }
}

struct MapShape: Shape {
    static let type = "map"
    let key: MemberShape
    let value: MemberShape
    func validate(using model: Model) throws {
        try key.validate(using: model)
        try value.validate(using: model)
    }
}

struct StructureShape: Shape {
    static let type = "structure"
    let members: [String: MemberShape]
    func validate(using model: Model) throws {
        try members.forEach { try $0.value.validate(using: model) }
    }
}

struct UnionShape: Shape {
    static let type = "union"
    let members: [String: MemberShape]
    func validate(using model: Model) throws {
        try members.forEach { try $0.value.validate(using: model) }
    }
}
