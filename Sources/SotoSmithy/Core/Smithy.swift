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
        
        registerTraitTypes(
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
            ExamplesTrait.self,
            ExternalDocumentationTrait.self,
            InternalTrait.self,
            SensitiveTrait.self,
            SinceTrait.self,
            TagsTrait.self,
            TitleTrait.self,
            UnstableTrait.self,
            // type refinement traits
            BoxTrait.self,
            ErrorTrait.self,
            // protocol traits
            ProtocolDefinitionTrait.self,
            JsonNameTrait.self,
            MediaTypeTrait.self,
            TimestampFormatTrait.self,
            // authentication traits
            AuthDefinitionTrait.self,
            HttpBasicAuthTrait.self,
            HttpDigestAuthTrait.self,
            HttpBearerAuthTrait.self,
            HttpApiKeyAuthTrait.self,
            OptionalAuthTrait.self,
            AuthTrait.self,
            // behaviour traits
            IdempotencyTokenTrait.self,
            IdempotentTrait.self,
            ReadonlyTrait.self,
            RetryableTrait.self,
            PaginatedTrait.self,
            HttpChecksumRequiredTrait.self,
            // resource traits
            NoReplaceTrait.self,
            ReferencesTrait.self,
            ResourceIdentifierTrait.self,
            // streaming traits
            StreamingTrait.self,
            RequiresLengthTrait.self,
            // http protocol binding traits
            HttpTrait.self,
            HttpErrorTrait.self,
            HttpHeaderTrait.self,
            HttpLabelTrait.self,
            HttpPayloadTrait.self,
            HttpPrefixHeadersTrait.self,
            HttpQueryTrait.self,
            HttpResponseCodeTrait.self,
            HttpCorsTrait.self,
            // xml binding traits
            XmlAttributeTrait.self,
            XmlFlattenedTrait.self,
            XmlNameTrait.self,
            XmlNamespaceTrait.self,
            // endpoint traits
            EndpointTrait.self,
            HostLabelTrait.self
        )
    }
    
    public func registerTraitTypes(_ traitTypes: Trait.Type ...) {
        TraitList.registerTraitTypes(traitTypes)
    }
    
    var preludeShapes: [ShapeId: Shape] = [
        "smithy.api#String": StringShape(traits: nil),
        "smithy.api#Blob": BlobShape(traits: nil),
        "smithy.api#BigInteger": BigIntegerShape(traits: nil),
        "smithy.api#BigDecimal": BigDecimalShape(traits: nil),
        "smithy.api#Timestamp": TimestampShape(traits: nil),
        "smithy.api#Document": DocumentShape(traits: nil),
        "smithy.api#Boolean": BooleanShape(traits: [BoxTrait()]),
        "smithy.api#PrimitiveBoolean": BooleanShape(traits: nil),
        "smithy.api#Byte": ByteShape(traits: [BoxTrait()]),
        "smithy.api#PrimitiveByte": ByteShape(traits: nil),
        "smithy.api#Short": ShortShape(traits: [BoxTrait()]),
        "smithy.api#PrimitiveShort": ShortShape(traits: nil),
        "smithy.api#Integer": IntegerShape(traits: [BoxTrait()]),
        "smithy.api#PrimitiveInteger": IntegerShape(traits: nil),
        "smithy.api#Long": LongShape(traits: [BoxTrait()]),
        "smithy.api#PrimitiveLong": LongShape(traits: nil),
        "smithy.api#Float": FloatShape(traits: [BoxTrait()]),
        "smithy.api#PrimitiveFloat": FloatShape(traits: nil),
        "smithy.api#Double": DoubleShape(traits: [BoxTrait()]),
        "smithy.api#PrimitiveDouble": DoubleShape(traits: nil),
    ]
}
