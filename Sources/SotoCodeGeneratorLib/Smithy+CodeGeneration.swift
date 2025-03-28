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

protocol SotoOutput {
    var output: String { get }
}

protocol AliasTrait: StaticTrait {
    var alias: String { get }
}

protocol ProtocolAliasTrait: StaticTrait {
    var alias: String { get }
}

protocol AwsServiceProtocol: SotoOutput {
    var nameTrait: ProtocolAliasTrait.Type { get }
    var requiresCollectionCoders: Bool { get }
}

// MARK: Alias traits

extension JsonNameTrait: ProtocolAliasTrait { var alias: String { value } }
extension XmlNameTrait: ProtocolAliasTrait { var alias: String { value } }
// going to have to assume EC2 name isn't used and use Header name
// extension AwsProtocolsEc2QueryNameTrait: AliasTrait { var alias: String { return value } }
extension HttpHeaderTrait: AliasTrait { var alias: String { value } }
extension HttpPrefixHeadersTrait: AliasTrait { var alias: String { value } }
extension HttpQueryTrait: AliasTrait { var alias: String { value } }

// MARK: Service protocol

extension AwsProtocolsRestJson1Trait: AwsServiceProtocol {
    var output: String { ".restjson" }
    var nameTrait: ProtocolAliasTrait.Type { JsonNameTrait.self }
    var requiresCollectionCoders: Bool { false }
}

extension AwsProtocolsAwsJson1_0Trait: AwsServiceProtocol {
    var output: String { ".json(version: \"1.0\")" }
    var nameTrait: ProtocolAliasTrait.Type { JsonNameTrait.self }
    var requiresCollectionCoders: Bool { false }
}

extension AwsProtocolsAwsJson1_1Trait: AwsServiceProtocol {
    var output: String { ".json(version: \"1.1\")" }
    var nameTrait: ProtocolAliasTrait.Type { JsonNameTrait.self }
    var requiresCollectionCoders: Bool { false }
}

extension AwsProtocolsAwsQueryTrait: AwsServiceProtocol {
    var output: String { ".query" }
    var nameTrait: ProtocolAliasTrait.Type { XmlNameTrait.self }
    var requiresCollectionCoders: Bool { true }
}

extension AwsProtocolsEc2QueryTrait: AwsServiceProtocol {
    var output: String { ".ec2" }
    var nameTrait: ProtocolAliasTrait.Type { XmlNameTrait.self }
    var requiresCollectionCoders: Bool { true }
}

extension AwsProtocolsRestXmlTrait: AwsServiceProtocol {
    var output: String { ".restxml" }
    var nameTrait: ProtocolAliasTrait.Type { XmlNameTrait.self }
    var requiresCollectionCoders: Bool { true }
}

// MARK: Shape types

extension BooleanShape: SotoOutput { var output: String { "Bool" } }
extension ByteShape: SotoOutput { var output: String { "Int8" } }
extension ShortShape: SotoOutput { var output: String { "Int16" } }
extension IntegerShape: SotoOutput { var output: String { "Int" } }
extension LongShape: SotoOutput { var output: String { "Int64" } }
extension FloatShape: SotoOutput { var output: String { "Float" } }
extension DoubleShape: SotoOutput { var output: String { "Double" } }
extension BigIntegerShape: SotoOutput { var output: String { "Int64" } }
extension BigDecimalShape: SotoOutput { var output: String { "Double" } }
extension TimestampShape: SotoOutput { var output: String { "Date" } }
extension DocumentShape: SotoOutput { var output: String { "AWSDocument" } }
extension UnitShape: SotoOutput { var output: String { "Void" } }

extension MemberShape {
    func output(_ model: Model) -> String {
        // assume model has been validated
        let memberShape = model.shape(for: self.target)!
        if memberShape is StringShape {
            if memberShape.hasTrait(type: EnumTrait.self) { return self.target.shapeName.toSwiftClassCase() }
            return "String"
        } else if memberShape is BlobShape {
            if self.hasTrait(type: HttpPayloadTrait.self) {
                return "AWSHTTPBody"
            } else if self.hasTrait(type: EventPayloadTrait.self) {
                return "AWSEventPayload"
            }
            return "AWSBase64Data"
        } else if memberShape is CollectionShape {
            if memberShape.hasTrait(type: StreamingTrait.self) {
                return "AWSEventStream<\(self.target.shapeName.toSwiftClassCase())>"
            } else {
                return self.target.shapeName.toSwiftClassCase()
            }
        } else if let listShape = memberShape as? ListShape {
            return "[\(listShape.member.output(model))]"
        } else if let setShape = memberShape as? SetShape {
            // Output sets as Arrays. Need to verify members are hashable before outputting as a Set
            return "[\(setShape.member.output(model))]"
        } else if let mapShape = memberShape as? MapShape {
            return "[\(mapShape.key.output(model)): \(mapShape.value.output(model))]"
        } else if let sotoMemberShape = memberShape as? SotoOutput {
            return sotoMemberShape.output
        }
        return "Unsupported"
    }

    func output(_ model: Model, withServiceName: String) -> String {
        // assume model has been validated
        let memberShape = model.shape(for: self.target)!
        if memberShape is StringShape {
            if memberShape.hasTrait(type: EnumTrait.self) { return "\(withServiceName).\(self.target.shapeName.toSwiftClassCase())" }
            return "String"
        } else if memberShape is BlobShape {
            if self.hasTrait(type: HttpPayloadTrait.self) { return "AWSHTTPBody" }
            return "AWSBase64Data"
        } else if memberShape is CollectionShape {
            return "\(withServiceName).\(self.target.shapeName.toSwiftClassCase())"
        } else if let listShape = memberShape as? ListShape {
            if listShape.hasTrait(type: UniqueItemsTrait.self) {
                return "Set<\(listShape.member.output(model, withServiceName: withServiceName))>"
            } else {
                return "[\(listShape.member.output(model, withServiceName: withServiceName))]"
            }
        } else if let setShape = memberShape as? SetShape {
            return "Set<\(setShape.member.output(model, withServiceName: withServiceName))>"
        } else if let mapShape = memberShape as? MapShape {
            return
                "[\(mapShape.key.output(model, withServiceName: withServiceName)): \(mapShape.value.output(model, withServiceName: withServiceName))]"
        } else if let sotoMemberShape = memberShape as? SotoOutput {
            return sotoMemberShape.output
        }
        return "Unsupported"
    }
}

protocol SotoEquatableShape {}

extension BooleanShape: SotoEquatableShape {}
extension ByteShape: SotoEquatableShape {}
extension ShortShape: SotoEquatableShape {}
extension IntegerShape: SotoEquatableShape {}
extension LongShape: SotoEquatableShape {}
extension FloatShape: SotoEquatableShape {}
extension DoubleShape: SotoEquatableShape {}
extension BigIntegerShape: SotoEquatableShape {}
extension BigDecimalShape: SotoEquatableShape {}
extension StringShape: SotoEquatableShape {}
extension TimestampShape: SotoEquatableShape {}
