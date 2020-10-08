//===----------------------------------------------------------------------===//
//
// This source file is part of the Soto for AWS open source project
//
// Copyright (c) 2017-2020 the Soto project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Soto project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

// traits required for loading AWS models and generating service files

import SotoSmithy

struct AwsProtocolsRestJson1Trait: EmptyTrait {
    static let staticName = "aws.protocols#restJson1"
}

struct AwsProtocolsAwsJson1_1Trait: EmptyTrait {
    static let staticName = "aws.protocols#awsJson1_1"
}

struct AwsProtocolsAwsJson1_0Trait: EmptyTrait {
    static let staticName = "aws.protocols#awsJson1_0"
}

struct AwsProtocolsAwsQueryTrait: EmptyTrait {
    static let staticName = "aws.protocols#awsQuery"
}

struct AwsProtocolsEc2QueryTrait: EmptyTrait {
    static let staticName = "aws.protocols#ec2Query"
}

struct AwsProtocolsRestXmlTrait: EmptyTrait {
    static let staticName = "aws.protocols#restXml"
}

struct AwsProtocolsEc2QueryNameTrait: StringTrait {
    static let staticName = "aws.protocols#ec2QueryName"
    var value: String
}

struct AwsAuthSigV4Trait: StaticTrait {
    static let staticName = "aws.auth#sigv4"
    let name: String
}

struct AwsAuthUnsignedPayloadTrait: EmptyTrait {
    static let staticName = "aws.auth#unsignedPayload"
}

struct AwsServiceTrait: StaticTrait {
    static let staticName = "aws.api#service"
    let sdkId: String
    let arnNamespace: String
    let cloudFormationName: String?
    let cloudTrailEventSource: String
}

struct AwsArnTrait: StaticTrait {
    static let staticName = "aws.api#arn"
    let template: String
    let absolute: Bool
    let noAccount: Bool
    let noRegion: Bool
}

struct AwsArnReferenceTrait: StaticTrait {
    static let staticName = "aws.api#arnReference"
    let service: String?
    let resource: String?
}

struct AwsClientEndpointDiscoveryTrait: StaticTrait {
    static let staticName = "aws.api#clientEndpointDiscovery"
    let operation: ShapeId
    let error: ShapeId
}
