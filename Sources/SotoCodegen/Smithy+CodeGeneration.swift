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

// MARK: Service protocol

extension AwsProtocolsRestJson1Trait: SotoOutput { var output: String { ".restjson" }}
extension AwsProtocolsAwsJson1_1Trait: SotoOutput { var output: String { ".json(version: \"1.0\")" } }
extension AwsProtocolsAwsJson1_0Trait: SotoOutput { var output: String { ".json(version: \"1.1\")" } }
extension AwsProtocolsAwsQueryTrait: SotoOutput { var output: String { ".query" } }
extension AwsProtocolsEc2QueryTrait: SotoOutput { var output: String { ".ec2" } }
extension AwsProtocolsRestXmlTrait: SotoOutput { var output: String { ".restxml" } }


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
