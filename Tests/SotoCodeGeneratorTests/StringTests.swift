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

@testable import SotoCodeGeneratorLib
import XCTest

/// Tests for String extensions
final class StringTests: XCTestCase {
    func testDropLast() {
        let s = "abc  "
        let result = s.dropLast { $0.isWhitespace }
        XCTAssertEqual(result, "abc")
    }

    func testDropLastEmptyString() {
        let s = "\t\t  "
        let result = s.dropLast { $0.isWhitespace }
        XCTAssertEqual(result, "")
    }
}
