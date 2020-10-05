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

import SotoSmithy
import XCTest

class TraitTests: XCTestCase {

    func testEnumTrait() throws {
        let json = """
        {
            "smithy.api#enum": [
                {
                    "value": "t2.nano",
                    "name": "T2_NANO",
                    "documentation": "T2 instances are ...",
                    "tags": [
                        "ebsOnly"
                    ]
                },
                {
                    "value": "t2.micro",
                    "name": "T2_MICRO",
                    "documentation": "T2 instances are ...",
                    "tags": [
                        "ebsOnly"
                    ]
                }
            ]
        }
        """
        _ = Smithy()
        let traitList = try JSONDecoder().decode(TraitList.self, from: Data(json.utf8))
        let enumTrait = traitList.trait(type: EnumTrait.self)
        XCTAssertEqual(enumTrait?.value[0].value, "t2.nano")
        XCTAssertEqual(enumTrait?.value[0].name, "T2_NANO")
        XCTAssertEqual(enumTrait?.value[0].documentation, "T2 instances are ...")
        XCTAssertEqual(enumTrait?.value[0].tags?[0], "ebsOnly")
    }

    func testIdRefTrait() throws {
        let json = """
        {
            "smithy.api#idRef": {
                "failWhenMissing": true,
                "selector": "integer"
            }
        }
        """
        _ = Smithy()
        let traitList = try JSONDecoder().decode(TraitList.self, from: Data(json.utf8))
        let idRefTrait = traitList.trait(type: IdRefTrait.self)
        XCTAssertEqual(idRefTrait?.failWhenMissing, true)
        XCTAssertEqual(idRefTrait?.selector, "integer")
    }

    func testLengthTrait() throws {
        let json = """
        {
            "smithy.api#length": {
                "min": 0,
                "max": 24
            }
        }
        """
        _ = Smithy()
        let traitList = try JSONDecoder().decode(TraitList.self, from: Data(json.utf8))
        let lengthTrait = traitList.trait(type: LengthTrait.self)
        XCTAssertEqual(lengthTrait?.min, 0)
        XCTAssertEqual(lengthTrait?.max, 24)
    }

    func testPatternTrait() throws {
        let json = """
        {
            "smithy.api#pattern": "$[a-z]*"
        }
        """
        _ = Smithy()
        let traitList = try JSONDecoder().decode(TraitList.self, from: Data(json.utf8))
        let patternTrait = traitList.trait(type: PatternTrait.self)
        XCTAssertEqual(patternTrait?.value, "$[a-z]*")
    }

    func testPrivateTrait() throws {
        let json = """
        {
            "smithy.api#private": {}
        }
        """
        _ = Smithy()
        let traitList = try JSONDecoder().decode(TraitList.self, from: Data(json.utf8))
        XCTAssertNotNil(traitList.trait(type: PrivateTrait.self))
    }

    func testRangeTrait() throws {
        let json = """
        {
            "smithy.api#range": {
                "min": 0,
                "max": 24.5
            }
        }
        """
        _ = Smithy()
        let traitList = try JSONDecoder().decode(TraitList.self, from: Data(json.utf8))
        let rangeTrait = traitList.trait(type: RangeTrait.self)
        XCTAssertEqual(rangeTrait?.min, 0)
        XCTAssertEqual(rangeTrait?.max, 24.5)
    }

    func testRequiredTrait() throws {
        let json = """
        {
            "smithy.api#required": {}
        }
        """
        _ = Smithy()
        let traitList = try JSONDecoder().decode(TraitList.self, from: Data(json.utf8))
        XCTAssertNotNil(traitList.trait(type: RequiredTrait.self))
    }

    func testDeprecatedTrait() throws {
        let json = """
        {
            "smithy.api#deprecated": {
                "message": "This shape is no longer used.",
                "since": "1.3"
            }
        }
        """
        _ = Smithy()
        let traitList = try JSONDecoder().decode(TraitList.self, from: Data(json.utf8))
        let deprecatedTrait = traitList.trait(type: DeprecatedTrait.self)
        XCTAssertEqual(deprecatedTrait?.message, "This shape is no longer used.")
        XCTAssertEqual(deprecatedTrait?.since, "1.3")
    }

    func testDocumentationTrait() throws {
        let json = """
        {
            "smithy.api#documentation": "Testing documentation trait"
        }
        """
        _ = Smithy()
        let traitList = try JSONDecoder().decode(TraitList.self, from: Data(json.utf8))
        let documentationTrait = traitList.trait(type: DocumentationTrait.self)
        XCTAssertEqual(documentationTrait?.value, "Testing documentation trait")
    }

    func testTimestampFormatTrait() throws {
        let json = """
        {
            "smithy.api#timestampFormat": "http-date"
        }
        """
        _ = Smithy()
        let traitList = try JSONDecoder().decode(TraitList.self, from: Data(json.utf8))
        let documentationTrait = traitList.trait(type: TimestampFormatTrait.self)
        XCTAssertEqual(documentationTrait?.format, .httpDate)
    }
}
