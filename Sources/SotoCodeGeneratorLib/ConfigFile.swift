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

struct ConfigFile: Decodable {
    struct ServiceConfig: Decodable {
        let operations: [String]?
    }

    enum AccessControl: String, Decodable {
        case `public`
        case `internal`
    }

    let services: [String: ServiceConfig]?
    let access: AccessControl?
}
