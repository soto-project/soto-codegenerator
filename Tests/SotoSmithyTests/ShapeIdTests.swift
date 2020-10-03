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

class ShapeIdTests: XCTestCase {
    func testNamespace() {
        XCTAssertEqual(ShapeId(rawValue: "namespace#test").namespace, "namespace")
        XCTAssertNil(ShapeId(rawValue: "test").namespace)
    }
    
    func testShape() {
        XCTAssertEqual(ShapeId(rawValue: "namespace#test").shape, "test")
        XCTAssertEqual(ShapeId(rawValue: "test").shape, "test")
        XCTAssertEqual(ShapeId(rawValue: "test$member").shape, "test")
        XCTAssertEqual(ShapeId(rawValue: "namespace#test$member").shape, "test")
        XCTAssertEqual(ShapeId(rawValue: "#test$").shape, "test")
    }
    
    func testMember() {
        XCTAssertNil(ShapeId(rawValue: "test").member)
        XCTAssertEqual(ShapeId(rawValue: "test$member").member, "member")
        XCTAssertEqual(ShapeId(rawValue: "namespace#test$member").member, "member")
    }
    
    func testRootShapeId() {
        XCTAssertEqual(ShapeId(rawValue: "test").rootShapeId, "test")
        XCTAssertEqual(ShapeId(rawValue: "namespace#test").rootShapeId, "namespace#test")
        XCTAssertEqual(ShapeId(rawValue: "test$member").rootShapeId, "test")
        XCTAssertEqual(ShapeId(rawValue: "namespace#test$member").rootShapeId, "namespace#test")
    }
}
