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

struct BlobShape: Shape {
    static let type = "blob"
}

struct BooleanShape: Shape {
    static let type = "boolean"
}

struct StringShape: Shape {
    static let type = "string"
}

struct ByteShape: Shape {
    static let type = "byte"
}

struct ShortShape: Shape {
    static let type = "short"
}

struct IntegerShape: Shape {
    static let type = "integer"
}

struct LongShape: Shape {
    static let type = "long"
}

struct FloatShape: Shape {
    static let type = "float"
}

struct DoubleShape: Shape {
    static let type = "double"
}

struct BigIntegerShape: Shape {
    static let type = "bigInteger"
}

struct BigDecimalShape: Shape {
    static let type = "bigDecimal"
}

struct TimestampShape: Shape {
    static let type = "timestamp"
}

struct DocumentShape: Shape {
    static let type = "document"
}
