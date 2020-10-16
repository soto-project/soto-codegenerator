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

extension Model {
    func patch(serviceName: String) throws {
        let patches:[String: [ShapeId: ShapePatch]] = [
            "CloudFront" : [
                "com.amazonaws.cloudfront#HttpVersion": EditEnumPatch(add: [.init(value: "HTTP1_1"), .init(value: "HTTP2")], remove: ["http1.1", "http2"])
            ],
            "Route53" : [
                "com.amazonaws.route53#ListHealthChecksResponse$Marker": RemoteTraitPatch(trait: RequiredTrait.self),
                "com.amazonaws.route53#ListHostedZonesResponse$Marker": RemoteTraitPatch(trait: RequiredTrait.self),
                "com.amazonaws.route53#ListReusableDelegationSetsResponse$Marker": RemoteTraitPatch(trait: RequiredTrait.self)
            ]
        ]
        if let servicePatches = patches[serviceName] {
            for patch in servicePatches {
                try apply(patch: patch.value, to: patch.key)
            }
        }
    }
    func apply(patch: ShapePatch, to shapeId: ShapeId) throws {
        if let shape = shape(for: shapeId) {
            patch.patch(shape: shape)
        }
    }
}
