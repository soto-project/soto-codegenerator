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

public struct Smithy {
    public init() {
        AnyShape.registerShapeTypes([
            // Simple shapes
            BlobShape.self,
            BooleanShape.self,
            StringShape.self,
            ByteShape.self,
            ShortShape.self,
            IntegerShape.self,
            LongShape.self,
            FloatShape.self,
            DoubleShape.self,
            BigIntegerShape.self,
            BigDecimalShape.self,
            TimestampShape.self,
            DocumentShape.self,
            // Aggregate shapes
            ListShape.self,
            SetShape.self,
            MapShape.self,
            StructureShape.self,
            UnionShape.self,
            // Service shapes
            ServiceShape.self,
            OperationShape.self,
            ResourceShape.self,
        ])
        
        TraitList.registerTraitTypes([
            // constraint traits
            EnumTrait.self,
            IdRefTrait.self,
            LengthTrait.self,
            PatternTrait.self,
            PrivateTrait.self,
            RangeTrait.self,
            RequiredTrait.self,
            UniqueItemsTrait.self,
            // documentation traits
            DeprecatedTrait.self,
            DocumentationTrait.self,
        ])
    }
}
