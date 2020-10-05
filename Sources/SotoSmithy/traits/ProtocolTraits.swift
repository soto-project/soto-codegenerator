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

public struct ProtocolDefinitionTrait: EmptyTrait {
    public static let name = "smithy.api#protocolDefinition"
    public init() {}
}

public struct JsonNameTrait: StringTrait {
    public static let name = "smithy.api#jsonName"
    public let string: String
    public init(string: String) {
        self.string = string
    }
}

public struct MediaTypeTrait: StringTrait {
    public static let name = "smithy.api#mediaType"
    public let string: String
    public init(string: String) {
        self.string = string
    }
}

public struct TimestampFormatTrait: Trait {
    public static let name = "smithy.api#timestampFormat"
    public enum TimestampFormat: String, Codable {
        case datetime = "date-time"
        case httpDate = "http-date"
        case epochSeconds = "epoch-seconds"
    }
    public let format: TimestampFormat
    public init(format: TimestampFormat) {
        self.format = format
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.format = try container.decode(TimestampFormat.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(format)
    }
}

