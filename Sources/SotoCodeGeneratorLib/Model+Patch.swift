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
import SotoSmithyAWS

extension Model {
    static let patches: [String: [ShapeId: ShapePatch]] = [
        "ACM": [
            "com.amazonaws.acm#KeyAlgorithm$RSA_1024": EditTraitPatch { _ in EnumValueTrait(value: .string("RSA-1024")) },
            "com.amazonaws.acm#KeyAlgorithm$RSA_2048": EditTraitPatch { _ in EnumValueTrait(value: .string("RSA-2048")) },
            "com.amazonaws.acm#KeyAlgorithm$RSA_3072": EditTraitPatch { _ in EnumValueTrait(value: .string("RSA-3072")) },
            "com.amazonaws.acm#KeyAlgorithm$RSA_4096": EditTraitPatch { _ in EnumValueTrait(value: .string("RSA-4096")) },
            "com.amazonaws.acm#KeyAlgorithm$EC_prime256v1": EditTraitPatch { _ in EnumValueTrait(value: .string("EC-prime256v1")) },
            "com.amazonaws.acm#KeyAlgorithm$EC_secp384r1": EditTraitPatch { _ in EnumValueTrait(value: .string("EC-secp384r1")) },
            "com.amazonaws.acm#KeyAlgorithm$EC_secp521r1": EditTraitPatch { _ in EnumValueTrait(value: .string("EC-secp521r1")) },
        ],
        "Amplify": [
            // https://github.com/soto-project/soto/issues/474
            "com.amazonaws.amplify#App$description": RemoveTraitPatch(trait: RequiredTrait.self),
            "com.amazonaws.amplify#App$environmentVariables": RemoveTraitPatch(trait: RequiredTrait.self),
            "com.amazonaws.amplify#App$repository": RemoveTraitPatch(trait: RequiredTrait.self),
        ],
        "BedrockAgentRuntime": [
            "com.amazonaws.bedrockagentruntime#FlowOutputEvent$nodeType": RemoveTraitPatch(trait: RequiredTrait.self),
        ],
        "CloudFront": [
            // `DistributionConfig` and `DistributionSummary` both use `HttpVersion`. One expects it to be lowercase
            // and the other expects it to be uppercase. Solution create new enum `UppercaseHttpVersion` for
            // `DistributionSummary` to use. See https://github.com/soto-project/soto/issues/567
            "com.amazonaws.cloudfront#UppercaseHttpVersion": CreateShapePatch(
                shape: StringShape(),
                patch: AddTraitPatch(trait: EnumTrait(value: .init([.init(value: "HTTP1_1"), .init(value: "HTTP2")])))
            ),
            "com.amazonaws.cloudfront#DistributionSummary$HttpVersion": EditShapePatch { (shape: MemberShape) in
                return MemberShape(target: "com.amazonaws.cloudfront#UppercaseHttpVersion", traits: shape.traits)
            }
        ],
        "CloudWatch": [
            // Dashboard not found code is the same as ResourceNotFound
            "com.amazonaws.cloudwatch#DashboardNotFoundError": RemoveTraitPatch(trait: AwsProtocolsAwsQueryErrorTrait.self),
        ],
        "Codeartifact": [
            // service name change
            "com.amazonaws.codeartifact#CodeArtifactControlPlaneService": EditTraitPatch { trait -> AwsServiceTrait in trait.with(sdkId: "CodeArtifact") },
        ],
        "CodestarNotifications": [
            // service name change
            "com.amazonaws.codestarnotifications#CodeStarNotifications_20191015": EditTraitPatch { trait -> AwsServiceTrait in trait.with(sdkId: "CodeStarNotifications") },
        ],
        "DynamoDB": [
            // Make TransactWriteItem an enum with associated values
            "com.amazonaws.dynamodb#TransactWriteItem": EditShapePatch { (shape: StructureShape) in return UnionShape(traits: shape.traits, members: shape.members) },
        ],
        "EC2": [
            "com.amazonaws.ec2#PlatformValues$Windows": EditTraitPatch { _ in EnumValueTrait(value: .string("windows")) },
            // make InstanceType and ArchitectureType extensible enums to avoid the situation where the
            // sdk service files cannot keep up with the changes coming from the services
            "com.amazonaws.ec2#InstanceType": AddTraitPatch(trait: SotoExtensibleEnumTrait()),
            "com.amazonaws.ec2#ArchitectureType": AddTraitPatch(trait: SotoExtensibleEnumTrait()),
        ],
        "ECRPUBLIC": [
            // service name change
            "com.amazonaws.ecrpublic#SpencerFrontendService": EditTraitPatch { trait -> AwsServiceTrait in trait.with(sdkId: "ECRPublic") },
        ],
        "ElasticLoadBalancing": [
            // https://github.com/soto-project/soto/pull/88
            "com.amazonaws.elasticloadbalancing#SecurityGroupOwnerAlias": ShapeTypePatch(shape: IntegerShape()),
        ],
        "Fis": [
            // service name change
            "com.amazonaws.fis#FaultInjectionSimulator": EditTraitPatch { trait -> AwsServiceTrait in trait.with(sdkId: "FIS") },
        ],
        "IAM": [
            // Missing Enum value
            "com.amazonaws.iam#PolicySourceType": AddShapeMemberPatch<EnumShape>(name: "IAM Policy"),
        ],
        "Identitystore": [
            // service name change
            "com.amazonaws.identitystore#AWSIdentityStore": EditTraitPatch { trait -> AwsServiceTrait in trait.with(sdkId: "IdentityStore") },
        ],
        "IotDeviceAdvisor": [
            // service name change
            "com.amazonaws.iotdeviceadvisor#IotSenateService": EditTraitPatch { trait -> AwsServiceTrait in trait.with(sdkId: "IoTDeviceAdvisor") },
        ],
        "Ivs": [
            // service name change
            "com.amazonaws.ivs#AmazonInteractiveVideoService": EditTraitPatch { trait -> AwsServiceTrait in trait.with(sdkId: "IVS") },
        ],
        "Lambda": [
            // Replace lambda ListFunctionsRequest.MasterRegion with SotoCore.Region.
            // See https://github.com/soto-project/soto/issues/382
            "com.amazonaws.lambda#SotoCore.Region": CreateShapePatch(
                shape: StringShape(),
                patch: MultiplePatch(
                    AddTraitPatch(trait: SotoStubTrait()),
                    AddTraitPatch(trait: EnumTrait(value: .init([])))
                )
            ),
            "com.amazonaws.lambda#ListFunctionsRequest$MasterRegion": EditShapePatch { (shape: MemberShape) in
                return MemberShape(target: "com.amazonaws.lambda#SotoCore.Region", traits: shape.traits)
            },
            // https://github.com/soto-project/soto/issues/720
            "com.amazonaws.lambda#LastUpdateStatusReasonCode": AddShapeMemberPatch<EnumShape>(
                name: "Creating",
                shapeId: "smithy.api#Unit",
                traits: [EnumValueTrait(value: .string("Creating"))]
            ),
        ],
        "MediaConvert": [
            "com.amazonaws.mediaconvert#__stringPatternS3": EditTraitPatch { _ in PatternTrait(value: "^s3:\\/\\/") }
        ],
        "Mq": [
            // service name change
            "com.amazonaws.mq#mq": EditTraitPatch { trait -> AwsServiceTrait in trait.with(sdkId: "MQ") },
        ],
        "RDSData": [
            // See https://github.com/soto-project/soto/issues/471
            "com.amazonaws.rdsdata#Arn": EditTraitPatch { trait in return LengthTrait(min: trait.min, max: 2048) },
        ],
        "Route53": [
            // pagination tokens in response shouldnt be required
            "com.amazonaws.route53#ListHealthChecksResponse$Marker": RemoveTraitPatch(trait: RequiredTrait.self),
            "com.amazonaws.route53#ListHostedZonesResponse$Marker": RemoveTraitPatch(trait: RequiredTrait.self),
            "com.amazonaws.route53#ListReusableDelegationSetsResponse$Marker": RemoveTraitPatch(trait: RequiredTrait.self),
        ],
        "S3": [
            // should be 64 bit number
            "com.amazonaws.s3#Size": ShapeTypePatch(shape: LongShape()),
            // https://github.com/soto-project/soto/issues/311
            "com.amazonaws.s3#CopySource": EditTraitPatch { _ in return PatternTrait(value: ".+\\/.+") },
            "com.amazonaws.s3#LifecycleRule$Filter": AddTraitPatch(trait: RequiredTrait()),
            // https://github.com/soto-project/soto/issues/502
            "com.amazonaws.s3#BucketLocationConstraint": MultiplePatch(
                AddShapeMemberPatch<EnumShape>(name: "us-east-1"),
                AddTraitPatch(trait: SotoExtensibleEnumTrait())
            ),
            // ListParts uses the IsTruncated flags to indicate when to finish pagination
            "com.amazonaws.s3#ListParts": AddTraitPatch(trait: SotoPaginationTruncatedTrait(isTruncated: "IsTruncated")),
            //
            "com.amazonaws.s3#StorageClass": AddShapeMemberPatch<EnumShape>(name: "NONE"),
        ],
        "S3Control": [
            // Similar to the same issue in S3
            "com.amazonaws.s3control#BucketLocationConstraint": MultiplePatch([
                AddShapeMemberPatch<EnumShape>(name: "us_east_1"),
                AddTraitPatch(trait: SotoExtensibleEnumTrait()),
            ]),
        ],
        "SQS": [
            "com.amazonaws.sqs#ChangeMessageVisibilityBatchResult$Successful": RemoveTraitPatch(trait: RequiredTrait.self),
            "com.amazonaws.sqs#ChangeMessageVisibilityBatchResult$Failed": RemoveTraitPatch(trait: RequiredTrait.self),
            "com.amazonaws.sqs#DeleteMessageBatchResult$Successful": RemoveTraitPatch(trait: RequiredTrait.self),
            "com.amazonaws.sqs#DeleteMessageBatchResult$Failed": RemoveTraitPatch(trait: RequiredTrait.self),
            "com.amazonaws.sqs#SendMessageBatchResult$Successful": RemoveTraitPatch(trait: RequiredTrait.self),
            "com.amazonaws.sqs#SendMessageBatchResult$Failed": RemoveTraitPatch(trait: RequiredTrait.self),
        ],
        "Savingsplans": [
            // service name change
            "com.amazonaws.savingsplans#AWSSavingsPlan": EditTraitPatch { trait -> AwsServiceTrait in trait.with(sdkId: "SavingsPlans") },
        ],
        "Textract": [
            "com.amazonaws.textract#ValueType$DATE": EditTraitPatch { _ in EnumValueTrait(value: .string("Date")) },
        ]
    ]
    func patch(serviceName: String) throws {
        if let servicePatches = Self.patches[serviceName] {
            for patch in servicePatches {
                try self.apply(patch: patch.value, to: patch.key)
            }
        }
    }

    func apply(patch: ShapePatch, to shapeId: ShapeId) throws {
        if let shape = shape(for: shapeId) {
            do {
                if let newShape = try patch.patch(shape: shape) {
                    if let member = shapeId.member,
                       let collectionShape = shapes[shapeId.rootShapeId] as? CollectionShape,
                       let newMemberShape = newShape as? MemberShape
                    {
                        collectionShape.members?[member] = newMemberShape
                    } else {
                        shapes[shapeId] = newShape
                    }
                }
            } catch let error as PatchError {
                throw PatchError(message: "\(shapeId): \(error.message)")
            }
        } else if let patch = patch as? CreateShapePatch {
            if let shape = try patch.create() {
                self.shapes[shapeId] = shape
            }
        } else {
            throw PatchError(message: "Shape \(shapeId) does not exist")
        }
    }
}

extension AwsServiceTrait {
    func with(sdkId: String) -> AwsServiceTrait {
        .init(
            sdkId: sdkId,
            arnNamespace: self.arnNamespace,
            cloudFormationName: self.cloudFormationName,
            cloudTrailEventSource: self.cloudTrailEventSource,
            endpointPrefix: self.endpointPrefix
        )
    }
}
