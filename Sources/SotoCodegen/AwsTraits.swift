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

struct AwsArnTrait: Trait {
    static let name = "aws.api#arn"
    let template: String
    let absolute: Bool
    let noAccount: Bool
    let noRegion: Bool
}

struct AwsServiceTrait: Trait {
    static let name = "aws.api#service"
    let sdkId: String
    let arnNamespace: String
    let cloudFormationName: String
    let cloudTrailEventSource: String
}

struct AwsAuthSigV4Trait: Trait {
    static let name = "aws.auth#sigv4"
    let name: String
}

struct AwsProtocolsRestJson1Trait: EmptyTrait {
    static let name = "aws.protocols#restJson1"
}
