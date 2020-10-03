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

struct ServiceShape: Shape {
    static let type = "service"
    let version: String
    let operations: [OperationMemberShape]?
    let resources: [ResourceMemberShape]?
}

struct OperationMemberShape: Shape {
    let target: ShapeId
    
    func validate(using model: Model) throws {
        guard let shape = model.shape(for: target) else { throw Smithy.ValidationError(reason: "Member references non-existent shape \(target)") }
        guard shape is OperationShape else { throw Smithy.ValidationError(reason: "Operation references illegal shape \(target)") }
    }
}

struct OperationShape: Shape {
    static let type = "operation"
    let input: MemberShape?
    let output: MemberShape?
    let errors: [MemberShape]?
}

struct ResourceMemberShape: Shape {
    let target: ShapeId
    
    func validate(using model: Model) throws {
        guard let shape = model.shape(for: target) else { throw Smithy.ValidationError(reason: "Member references non-existent shape \(target)") }
        guard shape is ResourceShape else { throw Smithy.ValidationError(reason: "Operation references illegal shape \(target)") }
    }
}

struct ResourceShape: Shape {
    static let type = "resource"
    let identifiers: [String: MemberShape]?
    let create: MemberShape?
    let put: MemberShape?
    let read: MemberShape?
    let update: MemberShape?
    let delete: MemberShape?
    let list: MemberShape?
    let operations: [MemberShape]?
    let collectionOperations: [MemberShape]?
    let resources: [MemberShape]?

}
