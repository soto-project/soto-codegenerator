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

    struct EndpointVariant: Decodable {
        var dnsSuffix: String?
        var hostname: String?
        var tags: Set<String>
    }

    struct Endpoint: Decodable {
        var credentialScope: CredentialScope?
        var hostname: String?
        var protocols: [String]?
        var signatureVersions: [SignatureVersion]?
        var variants: [EndpointVariant]?
        var deprecated: Bool?

        func applyingDefaults(_ defaults: Defaults) -> Endpoint {
            return .init(
                credentialScope: self.credentialScope ?? defaults.credentialScope,
                hostname: self.hostname ?? defaults.hostname,
                protocols: self.protocols ?? defaults.protocols,
                signatureVersions: self.signatureVersions ?? defaults.signatureVersions,
                variants: self.variants ?? defaults.variants,
                deprecated: self.deprecated
            )
        }

        func applyingGlobalDefaults(_ defaults: Defaults) -> Endpoint {
            var variants = self.variants
            if variants != nil {
                variants = variants!.map { variant in
                    if variant.hostname == nil {
                        let hostname = defaults.variants?.first(where: { $0.tags == variant.tags })?.hostname
                        return .init(dnsSuffix: variant.dnsSuffix, hostname: hostname, tags: variant.tags)
                    }
                    return variant
                }
            }
            return .init(
                credentialScope: self.credentialScope ?? defaults.credentialScope,
                hostname: self.hostname ?? defaults.hostname,
                protocols: self.protocols ?? defaults.protocols,
                signatureVersions: self.signatureVersions ?? defaults.signatureVersions,
                variants: variants,
                deprecated: self.deprecated
            )
        }
    }

    struct Defaults: Decodable {
        var credentialScope: CredentialScope?
        var hostname: String?
        var protocols: [String]?
        var signatureVersions: [SignatureVersion]?
        var variants: [EndpointVariant]?
    }

    struct RegionDesc: Decodable {
        var description: String
    }

    struct Service: Decodable {
        var defaults: Defaults?
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
