//===----------------------------------------------------------------------===//
//
// This source file is part of the Soto for AWS open source project
//
// Copyright (c) 2017-2023 the Soto project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Soto project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
struct ConfigFile: Decodable {
    struct ServiceConfig: Decodable {
        let operations: [String]?
    }

    let services: [String: ServiceConfig]?
}

extension ConfigFile {
    
   static func decodeFrom(file configFile: String) throws -> Self {
        let data = try Data(contentsOf: URL(fileURLWithPath: configFile))
        let sotoConfig = try JSONDecoder().decode(ConfigFile.self, from: data)
        return sotoConfig
    }
}
