//===----------------------------------------------------------------------===//
//
// This source file is part of the Soto for AWS open source project
//
// Copyright (c) 2020 the Soto project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Soto project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import SotoSmithy
import XCTest

class ModelTests: XCTestCase {
    func testVersion() throws {
        let json = #"{"smithy": "1.0"}"#
        let model = try JSONDecoder().decode(Model.self, from: Data(json.utf8))
        XCTAssertEqual(model.version, "1.0")
    }

    func testShapesType() throws {
        let json = """
        {
            "smithy": "1.0",
            "shapes": {
                "smithy.example#Blob": {
                    "type": "blob"
                }
            }
        }
        """
        let model = try JSONDecoder().decode(Model.self, from: Data(json.utf8))
        try model.validate()
        XCTAssertEqual(model.version, "1.0")
        XCTAssertNotNil(model.shapes?[ShapeId(rawValue:"smithy.example#Blob")])
    }
}


