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

protocol ProtocolAliasTrait: StaticTrait {
    var aliasName: String { get }
}

protocol AwsServiceProtocol: SotoOutput {
    var nameTrait: ProtocolAliasTrait.Type { get }
}

// MARK: Service protocol

extension JsonNameTrait: ProtocolAliasTrait { var aliasName: String { return value } }
extension XmlNameTrait: ProtocolAliasTrait { var aliasName: String { return value } }
extension AwsProtocolsEc2QueryNameTrait: ProtocolAliasTrait { var aliasName: String { return value } }

extension AwsProtocolsRestJson1Trait: AwsServiceProtocol {
    var output: String { ".restjson" }
    var nameTrait: ProtocolAliasTrait.Type { return JsonNameTrait.self }
}
extension AwsProtocolsAwsJson1_0Trait: AwsServiceProtocol {
    var output: String { ".json(version: \"1.0\")" }
    var nameTrait: ProtocolAliasTrait.Type { return JsonNameTrait.self }
}
extension AwsProtocolsAwsJson1_1Trait: AwsServiceProtocol {
    var output: String { ".json(version: \"1.1\")" }
    var nameTrait: ProtocolAliasTrait.Type { return JsonNameTrait.self }
}
extension AwsProtocolsAwsQueryTrait: AwsServiceProtocol {
    var output: String { ".query" }
    var nameTrait: ProtocolAliasTrait.Type { return XmlNameTrait.self }
}
extension AwsProtocolsEc2QueryTrait: AwsServiceProtocol {
    var output: String { ".ec2" }
    var nameTrait: ProtocolAliasTrait.Type { return XmlNameTrait.self }
}
extension AwsProtocolsRestXmlTrait: AwsServiceProtocol {
    var output: String { ".restxml" }
    var nameTrait: ProtocolAliasTrait.Type { return AwsProtocolsEc2QueryNameTrait.self }
}


// MARK: Shape types

extension BlobShape: SotoOutput { var output: String { "Data" } }
extension BooleanShape: SotoOutput { var output: String { "Bool" } }
extension StringShape: SotoOutput { var output: String { "String" } }
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
        if let sotoMemberShape = memberShape as? SotoOutput {
            return sotoMemberShape.output
        } else if memberShape is CollectionShape {
            return self.target.shapeName
        } else if let listShape = memberShape as? ListShape {
            return "[\(listShape.member.output(model))]"
        } else if let mapShape = memberShape as? MapShape {
            return "[\(mapShape.key.output(model)): \(mapShape.value.output(model))]"
        }
        return "Unsupported"
    }
}
