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
}

public struct BooleanShape: Shape {
    public static let type = "boolean"
}

public struct StringShape: Shape {
    public static let type = "string"
}

public struct ByteShape: Shape {
    public static let type = "byte"
}

public struct ShortShape: Shape {
    public static let type = "short"
}

public struct IntegerShape: Shape {
    public static let type = "integer"
}

public struct LongShape: Shape {
    public static let type = "long"
}

public struct FloatShape: Shape {
    public static let type = "float"
}

public struct DoubleShape: Shape {
    public static let type = "double"
}

public struct BigIntegerShape: Shape {
    public static let type = "bigInteger"
}

public struct BigDecimalShape: Shape {
    public static let type = "bigDecimal"
}

public struct TimestampShape: Shape {
    public static let type = "timestamp"
}

public struct DocumentShape: Shape {
    public static let type = "document"
}
