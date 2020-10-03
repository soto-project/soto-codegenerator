import XCTest

import soto_codegenTests

var tests = [XCTestCaseEntry]()
tests += soto_codegenTests.allTests()
XCTMain(tests)
