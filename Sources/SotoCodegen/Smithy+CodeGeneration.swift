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

// MARK: Service protocol

protocol AwsServiceProtocolTrait {
    var output: String { get }
}

extension AwsProtocolsRestJson1Trait: AwsServiceProtocolTrait {
    var output: String { ".restjson" }
}

extension AwsProtocolsAwsJson1_1Trait: AwsServiceProtocolTrait {
    var output: String { ".json(version: \"1.0\")" }
}

extension AwsProtocolsAwsJson1_0Trait: AwsServiceProtocolTrait {
    var output: String { ".json(version: \"1.1\")" }
}

extension AwsProtocolsAwsQueryTrait: AwsServiceProtocolTrait {
    var output: String { ".query" }
}

extension AwsProtocolsEc2QueryTrait: AwsServiceProtocolTrait {
    var output: String { ".ec2" }
}

extension AwsProtocolsRestXmlTrait: AwsServiceProtocolTrait {
    var output: String { ".restxml" }
}
