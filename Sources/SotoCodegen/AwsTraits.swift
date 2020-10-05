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

import SotoSmithy

struct AwsProtocolsRestJson1Trait: EmptyTrait {
    static let name = "aws.protocols#restJson1"
}

struct AwsProtocolsAwsJson1_1Trait: EmptyTrait {
    static let name = "aws.protocols#awsJson1_1"
}

struct AwsProtocolsAwsJson1_0Trait: EmptyTrait {
    static let name = "aws.protocols#awsJson1_0"
}

struct AwsProtocolsAwsQueryTrait: EmptyTrait {
    static let name = "aws.protocols#awsQuery"
}

struct AwsProtocolsEc2QueryTrait: EmptyTrait {
    static let name = "aws.protocols#ec2Query"
}

struct AwsProtocolsRestXmlTrait: EmptyTrait {
    static let name = "aws.protocols#restXml"
}

struct AwsProtocolsEc2QueryNameTrait: StringTrait {
    static let name = "aws.protocols#ec2QueryName"
    var value: String
}

struct AwsAuthSigV4Trait: Trait {
    static let name = "aws.auth#sigv4"
    let name: String
}

struct AwsAuthUnsignedPayloadTrait: EmptyTrait {
    static let name = "aws.auth#unsignedPayload"
}

struct AwsServiceTrait: Trait {
    static let name = "aws.api#service"
    let sdkId: String
    let arnNamespace: String
    let cloudFormationName: String?
    let cloudTrailEventSource: String
}

struct AwsArnTrait: Trait {
    static let name = "aws.api#arn"
    let template: String
    let absolute: Bool
    let noAccount: Bool
    let noRegion: Bool
}

struct AwsArnReferenceTrait: Trait {
    static let name = "aws.api#arnReference"
    let service: String?
    let resource: String?
}

struct AwsClientEndpointDiscoveryTrait: Trait {
    static let name = "aws.api#clientEndpointDiscovery"
    let operation: ShapeId
    let error: ShapeId
}
