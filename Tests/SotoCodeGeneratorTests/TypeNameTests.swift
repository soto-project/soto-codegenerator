//===----------------------------------------------------------------------===//
//
// This source file is part of the Soto for AWS open source project
//
// Copyright (c) 2017-2021 the Soto project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Soto project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import SotoCodeGeneratorLib
import XCTest

final class TypeNameTests: XCTestCase {
    func testLabels() {
        XCTAssertEqual("testLabel".toSwiftLabelCase(), "testLabel")
        XCTAssertEqual("test-label".toSwiftLabelCase(), "testLabel")
        XCTAssertEqual("TEST-LABEL".toSwiftLabelCase(), "testLabel")
        XCTAssertEqual("TEST-label".toSwiftLabelCase(), "testLabel")
        XCTAssertEqual("test_label".toSwiftLabelCase(), "testLabel")
        XCTAssertEqual("TEST_LABEL".toSwiftLabelCase(), "testLabel")
        XCTAssertEqual("TEST_label".toSwiftLabelCase(), "testLabel")
        XCTAssertEqual("TESTLabel".toSwiftLabelCase(), "testLabel")
    }

    func testVariableNames() {
        XCTAssertEqual("testVariable".toSwiftVariableCase(), "testVariable")
        XCTAssertEqual("test-variable".toSwiftVariableCase(), "testVariable")
        XCTAssertEqual("TEST-VARIABLE".toSwiftVariableCase(), "testVariable")
        XCTAssertEqual("TEST-variable".toSwiftVariableCase(), "testVariable")
        XCTAssertEqual("test_variable".toSwiftVariableCase(), "testVariable")
        XCTAssertEqual("TEST_VARIABLE".toSwiftVariableCase(), "testVariable")
        XCTAssertEqual("TEST_variable".toSwiftVariableCase(), "testVariable")
        XCTAssertEqual("TESTVariable".toSwiftVariableCase(), "testVariable")
        XCTAssertEqual("async".toSwiftVariableCase(), "`async`")
        XCTAssertEqual("for".toSwiftVariableCase(), "`for`")
        XCTAssertEqual("while".toSwiftVariableCase(), "`while`")
        XCTAssertEqual("repeat".toSwiftVariableCase(), "`repeat`")
    }
    
    func testClassNames() {
        XCTAssertEqual("testLabel".toSwiftClassCase(), "TestLabel")
        XCTAssertEqual("test-label".toSwiftClassCase(), "TestLabel")
        XCTAssertEqual("TEST-LABEL".toSwiftClassCase(), "TESTLABEL")
        XCTAssertEqual("TEST-label".toSwiftClassCase(), "TESTLabel")
        XCTAssertEqual("test_label".toSwiftClassCase(), "TestLabel")
        XCTAssertEqual("TEST_LABEL".toSwiftClassCase(), "TESTLABEL")
        XCTAssertEqual("TEST_label".toSwiftClassCase(), "TESTLabel")
        XCTAssertEqual("TESTLabel".toSwiftClassCase(), "TESTLabel")
    }
}
