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

public struct Model: Codable {
    static let smithy = Smithy()
    let version: String
    let metadata: [String: String]?
    let shapes: [ShapeId: AnyShape]?
    
    public init(from decoder: Decoder) throws {
        _ = Self.smithy
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try container.decode(String.self, forKey: .version)
        self.metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata)
        if let shapes = try container.decodeIfPresent([String: AnyShape].self, forKey: .shapes) {
            self.shapes = .init(uniqueKeysWithValues: shapes.map { (ShapeId(rawValue: $0.key), $0.value) } )
        } else {
            self.shapes = nil
        }
    }
    
    public func shape(for identifier: ShapeId) -> Shape? {
        return shapes?[identifier]?.shapeSelf
    }
    
    public func validate() throws {
        try shapes?.forEach { try $0.value.validate(using: self) }
    }
    
    private enum CodingKeys: String, CodingKey {
        case version = "smithy"
        case metadata
        case shapes
    }
}
