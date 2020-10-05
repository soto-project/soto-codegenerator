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
import Foundation

public struct MetadataValue {
    public let value: Any
    public init(value: Any) {
        self.value = value
    }
}

extension MetadataValue: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.init(value: NSNull())
        } else if let bool = try? container.decode(Bool.self) {
            self.init(value: bool)
        } else if let int = try? container.decode(Int.self) {
            self.init(value: int)
        } else if let uint = try? container.decode(UInt.self) {
            self.init(value: uint)
        } else if let double = try? container.decode(Double.self) {
            self.init(value: double)
        } else if let string = try? container.decode(String.self) {
            self.init(value: string)
        } else if let array = try? container.decode([MetadataValue].self) {
            self.init(value: array.map { $0.value })
        } else if let dictionary = try? container.decode([String: MetadataValue].self) {
            self.init(value: dictionary.mapValues { $0.value })
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyDecodable value cannot be decoded")
        }

    }
}
