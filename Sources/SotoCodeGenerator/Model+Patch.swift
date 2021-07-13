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
            "Amplify": [
                "com.amazonaws.amplify#App$description": RemoveTraitPatch(trait: RequiredTrait.self),
                "com.amazonaws.amplify#App$environmentVariables": RemoveTraitPatch(trait: RequiredTrait.self),
                "com.amazonaws.amplify#App$repository": RemoveTraitPatch(trait: RequiredTrait.self),
            ],
            "CloudFront" : [
                "com.amazonaws.cloudfront#HttpVersion": EditEnumPatch(add: [.init(value: "HTTP1_1"), .init(value: "HTTP2")], remove: ["http1.1", "http2"]),
            ],
            "CodeGuruProfiler": [
                "com.amazonaws.codeguruprofiler#Channels": EditShapePatch { (shape: SetShape) in return ListShape(traits: shape.traits, member: shape.member) }
            ],
            /*"CloudWatch": [
                // Patch error shape to avoid warning in generated code. Both errors have the same code "ResourceNotFound"
                ReplacePatch(PatchKeyPath2(\.operations["GetDashboard"], \.errors[1].shapeName), value: "ResourceNotFoundException", originalValue: "DashboardNotFoundError"),
                ReplacePatch(PatchKeyPath2(\.operations["DeleteDashboards"], \.errors[1].shapeName), value: "ResourceNotFoundException", originalValue: "DashboardNotFoundError"),
            ],*/
            "CognitoIdentityProvider": [
                "com.amazonaws.cognitoidentityprovider#UserStatusType": EditEnumPatch(add: [.init(value: "EXTERNAL_PROVIDER")]),
            ],
            "ComprehendMedical": [
                "com.amazonaws.comprehendmedical#EntitySubType": EditEnumPatch(add: [.init(value: "DX_NAME")]),
            ],
            "DynamoDB": [
                "com.amazonaws.dynamodb#AttributeValue": EditShapePatch { (shape: StructureShape) in return UnionShape(traits: shape.traits, members: shape.members) },
                "com.amazonaws.dynamodb#TransactWriteItem": EditShapePatch { (shape: StructureShape) in return UnionShape(traits: shape.traits, members: shape.members) },
            ],
            "EC2": [
                "com.amazonaws.ec2#PlatformValues": EditEnumPatch(add: [.init(value: "windows")], remove: ["Windows"]),
                "com.amazonaws.ec2#InstanceType": AddTraitPatch(trait: SotoExtensibleEnumTrait()),
                "com.amazonaws.ec2#ArchitectureType": AddTraitPatch(trait: SotoExtensibleEnumTrait()),
            ],
            "ECS": [
                "com.amazonaws.ecs#PropagateTags": EditEnumPatch(add: [.init(value: "NONE")]),
            ],
            "ElasticLoadBalancing": [
                "com.amazonaws.elasticloadbalancing#SecurityGroupOwnerAlias": ShapeTypePatch(shape: IntegerShape()),
            ],
            "IAM": [
                "com.amazonaws.iam#PolicySourceType": EditEnumPatch(add: [.init(value: "IAM Policy")]),
            ],
            /*"Lambda": [
                //AddDictionaryPatch(PatchKeyPath1(\.shapes), key: "SotoCore.Region", value: Shape(type: .stub, name: "SotoCore.Region")),
                //ReplacePatch(PatchKeyPath4(\.shapes["ListFunctionsRequest"], \.type.structure, \.members["MasterRegion"], \.shapeName), value: "SotoCore.Region", originalValue: "MasterRegion"),
            ],*/
            "RDSData": [
                "com.amazonaws.rdsdata#Arn": EditTraitPatch { trait in return LengthTrait(min: trait.min, max: 2048) },
            ],
            "Route53" : [
                "com.amazonaws.route53#ListHealthChecksResponse$Marker": RemoveTraitPatch(trait: RequiredTrait.self),
                "com.amazonaws.route53#ListHostedZonesResponse$Marker": RemoveTraitPatch(trait: RequiredTrait.self),
                "com.amazonaws.route53#ListReusableDelegationSetsResponse$Marker": RemoveTraitPatch(trait: RequiredTrait.self),
            ],
            "S3": [
                "com.amazonaws.s3#ReplicationStatus": EditEnumPatch(add: [.init(value: "COMPLETED")], remove: ["COMPLETE"]),
                "com.amazonaws.s3#Size": ShapeTypePatch(shape: LongShape()),
                "com.amazonaws.s3#CopySource": EditTraitPatch { trait in return PatternTrait(value: ".+\\/.+") },
                "com.amazonaws.s3#LifecycleRule$Filter": AddTraitPatch(trait: RequiredTrait()),
                "com.amazonaws.s3#BucketLocationConstraint": MultiplePatch([
                    EditEnumPatch(add: [.init(value: "us-east-1")]),
                    AddTraitPatch(trait: SotoExtensibleEnumTrait())
                ]),
                "com.amazonaws.s3#StreamingBlob": AddTraitPatch(trait: RequiresLengthTrait()),
            ],
            "S3Control": [
                "com.amazonaws.s3#BucketLocationConstraint": MultiplePatch([
                    EditEnumPatch(add: [.init(value: "us-east-1")]),
                    AddTraitPatch(trait: SotoExtensibleEnumTrait())
                ]),
            ],
            "SageMaker": [
                "com.amazonaws.sagemaker#ListFeatureGroupsResponse$NextToken": RemoveTraitPatch(trait: RequiredTrait.self),
            ],
        ]
        if let servicePatches = patches[serviceName] {
            for patch in servicePatches {
                try apply(patch: patch.value, to: patch.key)
            }
        }
    }
    
    func apply(patch: ShapePatch, to shapeId: ShapeId) throws {
        if let shape = shape(for: shapeId) {
            if let newShape = patch.patch(shape: shape) {
                shapes[shapeId] = newShape
            }
        }
    }
}
