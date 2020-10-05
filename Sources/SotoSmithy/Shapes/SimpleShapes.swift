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

public struct BlobShape: Shape {
    public static let type = "blob"
    public let traits: TraitList?
}

public struct BooleanShape: Shape {
    public static let type = "boolean"
    public let traits: TraitList?
}

public struct StringShape: Shape {
    public static let type = "string"
    public let traits: TraitList?
}

public struct ByteShape: Shape {
    public static let type = "byte"
    public let traits: TraitList?
}

public struct ShortShape: Shape {
    public static let type = "short"
    public let traits: TraitList?
}

public struct IntegerShape: Shape {
    public static let type = "integer"
    public let traits: TraitList?
}

public struct LongShape: Shape {
    public static let type = "long"
    public let traits: TraitList?
}

public struct FloatShape: Shape {
    public static let type = "float"
    public let traits: TraitList?
}

public struct DoubleShape: Shape {
    public static let type = "double"
    public let traits: TraitList?
}

public struct BigIntegerShape: Shape {
    public static let type = "bigInteger"
    public let traits: TraitList?
}

public struct BigDecimalShape: Shape {
    public static let type = "bigDecimal"
    public let traits: TraitList?
}

public struct TimestampShape: Shape {
    public static let type = "timestamp"
    public let traits: TraitList?
}

public struct DocumentShape: Shape {
    public static let type = "document"
    public let traits: TraitList?
}
