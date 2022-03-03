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

protocol AwsServiceProtocol: SotoOutput {
    var nameTrait: AliasTrait.Type { get }
    var requiresCollectionCoders: Bool { get }
}

// MARK: Alias traits

extension JsonNameTrait: AliasTrait { var alias: String { return value } }
extension XmlNameTrait: AliasTrait { var alias: String { return value } }
// going to have to assume EC2 name isn't used and use Header name
// extension AwsProtocolsEc2QueryNameTrait: AliasTrait { var alias: String { return value } }
extension HttpHeaderTrait: AliasTrait { var alias: String { return value } }
extension HttpPrefixHeadersTrait: AliasTrait { var alias: String { return value } }
extension HttpQueryTrait: AliasTrait { var alias: String { return value } }

// MARK: Service protocol

extension AwsProtocolsRestJson1Trait: AwsServiceProtocol {
    var output: String { ".restjson" }
    var nameTrait: AliasTrait.Type { return JsonNameTrait.self }
    var requiresCollectionCoders: Bool { return false }
}

extension AwsProtocolsAwsJson1_0Trait: AwsServiceProtocol {
    var output: String { ".json(version: \"1.0\")" }
    var nameTrait: AliasTrait.Type { return JsonNameTrait.self }
    var requiresCollectionCoders: Bool { return false }
}

extension AwsProtocolsAwsJson1_1Trait: AwsServiceProtocol {
    var output: String { ".json(version: \"1.1\")" }
    var nameTrait: AliasTrait.Type { return JsonNameTrait.self }
    var requiresCollectionCoders: Bool { return false }
}

extension AwsProtocolsAwsQueryTrait: AwsServiceProtocol {
    var output: String { ".query" }
    var nameTrait: AliasTrait.Type { return XmlNameTrait.self }
    var requiresCollectionCoders: Bool { return true }
}

extension AwsProtocolsEc2QueryTrait: AwsServiceProtocol {
    var output: String { ".ec2" }
    var nameTrait: AliasTrait.Type { return XmlNameTrait.self }
    var requiresCollectionCoders: Bool { return true }
}

extension AwsProtocolsRestXmlTrait: AwsServiceProtocol {
    var output: String { ".restxml" }
    var nameTrait: AliasTrait.Type { return XmlNameTrait.self }
    var requiresCollectionCoders: Bool { return true }
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
extension TimestampShape: SotoOutput { var output: String { "Date" }}
extension DocumentShape: SotoOutput { var output: String { "String" }}

extension MemberShape {
    func output(_ model: Model) -> String {
        // assume model has been validated
        let memberShape = model.shape(for: self.target)!
        if memberShape is StringShape {
            if memberShape.hasTrait(type: EnumTrait.self) { return self.target.shapeName.toSwiftClassCase() }
            return "String"
        } else if memberShape is BlobShape {
            if self.hasTrait(type: HttpPayloadTrait.self) { return "AWSPayload" }
            return "Data"
        } else if memberShape is CollectionShape {
            return self.target.shapeName.toSwiftClassCase()
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
            if self.hasTrait(type: HttpPayloadTrait.self) { return "AWSPayload" }
            return "Data"
        } else if memberShape is CollectionShape {
            return "\(withServiceName).\(self.target.shapeName.toSwiftClassCase())"
        } else if let listShape = memberShape as? ListShape {
            return "[\(listShape.member.output(model, withServiceName: withServiceName))]"
        } else if let setShape = memberShape as? SetShape {
            return "Set<\(setShape.member.output(model, withServiceName: withServiceName))>"
        } else if let mapShape = memberShape as? MapShape {
            return "[\(mapShape.key.output(model, withServiceName: withServiceName)): \(mapShape.value.output(model, withServiceName: withServiceName))]"
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
