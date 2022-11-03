//===----------------------------------------------------------------------===//
//
// This source file is part of the Soto for AWS open source project
//
// Copyright (c) 2017-2022 the Soto project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Soto project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

enum SignatureVersion: String, Decodable {
    case v2
    case v4
    case s3
    case s3v4
}

struct Endpoints: Decodable {
    struct CredentialScope: Decodable {
        var region: String?
        var service: String?
    }

    struct Defaults: Decodable {
        var credentialScope: CredentialScope?
        var hostname: String?
        var protocols: [String]?
        var signatureVersions: [SignatureVersion]?
    }

    struct RegionDesc: Decodable {
        var description: String
    }

    struct Service: Decodable {
        struct Endpoint: Decodable {
            var credentialScope: CredentialScope?
            var hostname: String?
            var protocols: [String]?
            var signatureVersions: [SignatureVersion]?
        }

        var defaults: Endpoint?
        var endpoints: [String: Endpoint]
        var isRegionalized: Bool?
        var partitionEndpoint: String?
    }

    struct Partition: Decodable {
        var defaults: Defaults
        var dnsSuffix: String
        var partition: String
        var partitionName: String
        var regionRegex: String
        var regions: [String: RegionDesc]
        var services: [String: Service]
    }

    var partitions: [Partition]
}
