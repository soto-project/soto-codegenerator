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

class ShapeTests: XCTestCase {

    func testBlobShape() throws {
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
        XCTAssert(model.shape(for:ShapeId(rawValue:"smithy.example#Blob")) is BlobShape)
    }

    func testBooleanShape() throws {
        let json = """
        {
            "smithy": "1.0",
            "shapes": {
                "smithy.example#Bool": {
                    "type": "boolean"
                }
            }
        }
        """
        let model = try JSONDecoder().decode(Model.self, from: Data(json.utf8))
        try model.validate()
        XCTAssert(model.shape(for:ShapeId(rawValue:"smithy.example#Bool")) is BooleanShape)
    }

    func testByteShape() throws {
        let json = """
        {
            "smithy": "1.0",
            "shapes": {
                "smithy.example#Byte": {
                    "type": "byte"
                }
            }
        }
        """
        let model = try JSONDecoder().decode(Model.self, from: Data(json.utf8))
        try model.validate()
        XCTAssert(model.shape(for:ShapeId(rawValue:"smithy.example#Byte")) is ByteShape)
    }

    func testShortShape() throws {
        let json = """
        {
            "smithy": "1.0",
            "shapes": {
                "smithy.example#Short": {
                    "type": "short"
                }
            }
        }
        """
        let model = try JSONDecoder().decode(Model.self, from: Data(json.utf8))
        try model.validate()
        XCTAssert(model.shape(for:ShapeId(rawValue:"smithy.example#Short")) is ShortShape)
    }

    func testIntegerShape() throws {
        let json = """
        {
            "smithy": "1.0",
            "shapes": {
                "smithy.example#Integer": {
                    "type": "integer"
                }
            }
        }
        """
        let model = try JSONDecoder().decode(Model.self, from: Data(json.utf8))
        try model.validate()
        XCTAssert(model.shape(for:ShapeId(rawValue:"smithy.example#Integer")) is IntegerShape)
    }

    func testLongShape() throws {
        let json = """
        {
            "smithy": "1.0",
            "shapes": {
                "smithy.example#Long": {
                    "type": "long"
                }
            }
        }
        """
        let model = try JSONDecoder().decode(Model.self, from: Data(json.utf8))
        try model.validate()
        XCTAssert(model.shape(for:ShapeId(rawValue:"smithy.example#Long")) is LongShape)
    }

    func testFloatShape() throws {
        let json = """
        {
            "smithy": "1.0",
            "shapes": {
                "smithy.example#Float": {
                    "type": "float"
                }
            }
        }
        """
        let model = try JSONDecoder().decode(Model.self, from: Data(json.utf8))
        try model.validate()
        XCTAssert(model.shape(for:ShapeId(rawValue:"smithy.example#Float")) is FloatShape)
    }

    func testDoubleShape() throws {
        let json = """
        {
            "smithy": "1.0",
            "shapes": {
                "smithy.example#Double": {
                    "type": "double"
                }
            }
        }
        """
        let model = try JSONDecoder().decode(Model.self, from: Data(json.utf8))
        try model.validate()
        XCTAssert(model.shape(for:ShapeId(rawValue:"smithy.example#Double")) is DoubleShape)
    }

    func testBigIntegerShape() throws {
        let json = """
        {
            "smithy": "1.0",
            "shapes": {
                "smithy.example#BigInteger": {
                    "type": "bigInteger"
                }
            }
        }
        """
        let model = try JSONDecoder().decode(Model.self, from: Data(json.utf8))
        try model.validate()
        XCTAssert(model.shape(for:ShapeId(rawValue:"smithy.example#BigInteger")) is BigIntegerShape)
    }

    func testBigDecimalShape() throws {
        let json = """
        {
            "smithy": "1.0",
            "shapes": {
                "smithy.example#BigDecimal": {
                    "type": "bigDecimal"
                }
            }
        }
        """
        let model = try JSONDecoder().decode(Model.self, from: Data(json.utf8))
        try model.validate()
        XCTAssert(model.shape(for:ShapeId(rawValue:"smithy.example#BigDecimal")) is BigDecimalShape)
    }

    func testTimestamp() throws {
        let json = """
        {
            "smithy": "1.0",
            "shapes": {
                "smithy.example#Timestamp": {
                    "type": "timestamp"
                }
            }
        }
        """
        let model = try JSONDecoder().decode(Model.self, from: Data(json.utf8))
        try model.validate()
        XCTAssert(model.shape(for:ShapeId(rawValue:"smithy.example#Timestamp")) is TimestampShape)
    }

    func testDocument() throws {
        let json = """
        {
            "smithy": "1.0",
            "shapes": {
                "smithy.example#Document": {
                    "type": "document"
                }
            }
        }
        """
        let model = try JSONDecoder().decode(Model.self, from: Data(json.utf8))
        try model.validate()
        XCTAssert(model.shape(for:ShapeId(rawValue:"smithy.example#Document")) is DocumentShape)
    }
    
    func testList() throws {
        let json = """
        {
            "smithy": "1.0",
            "shapes": {
                "smithy.example#Integer": { "type": "integer" },
                "smithy.example#List": {
                    "type": "list",
                    "member": { "target": "smithy.example#Integer" }
                }
            }
        }
        """
        let model = try JSONDecoder().decode(Model.self, from: Data(json.utf8))
        try model.validate()
        let list = try XCTUnwrap(model.shape(for:ShapeId(rawValue:"smithy.example#List")) as? ListShape)
        XCTAssertEqual(list.member.target, ShapeId(rawValue: "smithy.example#Integer"))
    }

    func testSet() throws {
        let json = """
        {
            "smithy": "1.0",
            "shapes": {
                "smithy.example#Integer": { "type": "integer" },
                "smithy.example#Set": {
                    "type": "set",
                    "member": { "target": "smithy.example#Integer" }
                }
            }
        }
        """
        let model = try JSONDecoder().decode(Model.self, from: Data(json.utf8))
        try model.validate()
        let set = try XCTUnwrap(model.shape(for:ShapeId(rawValue:"smithy.example#Set")) as? SetShape)
        XCTAssertEqual(set.member.target, ShapeId(rawValue: "smithy.example#Integer"))
    }

    func testMap() throws {
        let json = """
        {
            "smithy": "1.0",
            "shapes": {
                "smithy.example#Key": { "type": "string" },
                "smithy.example#Value": { "type": "integer" },
                "smithy.example#Map": {
                    "type": "map",
                    "key": { "target": "smithy.example#Key" },
                    "value": { "target": "smithy.example#Value" }
                }
            }
        }
        """
        let model = try JSONDecoder().decode(Model.self, from: Data(json.utf8))
        try model.validate()
        let map = try XCTUnwrap(model.shape(for:ShapeId(rawValue:"smithy.example#Map")) as? MapShape)
        XCTAssertEqual(map.key.target, ShapeId(rawValue: "smithy.example#Key"))
        XCTAssertEqual(map.value.target, ShapeId(rawValue: "smithy.example#Value"))
    }

    func testStructure() throws {
        let json = """
        {
            "smithy": "1.0",
            "shapes": {
                "smithy.example#Name": { "type": "string" },
                "smithy.example#Age": { "type": "integer" },
                "smithy.example#Structure": {
                    "type": "structure",
                    "members" : {
                        "name": { "target": "smithy.example#Name" },
                        "age": { "target": "smithy.example#Age" }
                    }
                }
            }
        }
        """
        let model = try JSONDecoder().decode(Model.self, from: Data(json.utf8))
        try model.validate()
        let structure = try XCTUnwrap(model.shape(for:ShapeId(rawValue:"smithy.example#Structure")) as? StructureShape)
        XCTAssertEqual(structure.members["name"]?.target, ShapeId(rawValue: "smithy.example#Name"))
        XCTAssertEqual(structure.members["age"]?.target, ShapeId(rawValue: "smithy.example#Age"))
    }

    func testUnion() throws {
        let json = """
        {
            "smithy": "1.0",
            "shapes": {
                "smithy.example#Name": { "type": "string" },
                "smithy.example#Age": { "type": "integer" },
                "smithy.example#Union": {
                    "type": "union",
                    "members" : {
                        "name": { "target": "smithy.example#Name" },
                        "age": { "target": "smithy.example#Age" }
                    }
                }
            }
        }
        """
        let model = try JSONDecoder().decode(Model.self, from: Data(json.utf8))
        try model.validate()
        let structure = try XCTUnwrap(model.shape(for:ShapeId(rawValue:"smithy.example#Union")) as? UnionShape)
        XCTAssertEqual(structure.members["name"]?.target, ShapeId(rawValue: "smithy.example#Name"))
        XCTAssertEqual(structure.members["age"]?.target, ShapeId(rawValue: "smithy.example#Age"))
    }

    func testService() throws {
        let json = """
        {
            "smithy": "1.0",
            "shapes": {
                "smithy.example#Service": {
                    "type": "service",
                    "version": "10-10-20"
                }
            }
        }
        """
        let model = try JSONDecoder().decode(Model.self, from: Data(json.utf8))
        try model.validate()
        let service = try XCTUnwrap(model.shape(for:ShapeId(rawValue:"smithy.example#Service")) as? ServiceShape)
        XCTAssertEqual(service.version, "10-10-20")
    }

    func testOperation() throws {
        let json = """
        {
            "smithy": "1.0",
            "shapes": {
                "smithy.example#Service": {
                    "type": "service",
                    "version": "10-10-20",
                    "operations": [
                        { "target": "smithy.example#Operation1" },
                        { "target": "smithy.example#Operation2" }
                    ]
                },
                "smithy.example#Operation1": {
                    "type": "operation",
                    "input": { "target": "smithy.example#Int" }
                },
                "smithy.example#Operation2": {
                    "type": "operation",
                    "output": { "target": "smithy.example#String" }
                },
                "smithy.example#Int": { "type": "integer" },
                "smithy.example#String": { "type": "string" },

            }
        }
        """
        let model = try JSONDecoder().decode(Model.self, from: Data(json.utf8))
        try model.validate()
        let service = try XCTUnwrap(model.shape(for:ShapeId(rawValue:"smithy.example#Service")) as? ServiceShape)
        let operations = try XCTUnwrap(service.operations)
        let operation1 = try XCTUnwrap(model.shape(for: operations[0].target) as? OperationShape)
        let operation2 = try XCTUnwrap(model.shape(for: operations[1].target) as? OperationShape)
        XCTAssertEqual(operation1.input?.target, ShapeId(rawValue: "smithy.example#Int"))
        XCTAssertEqual(operation2.output?.target, ShapeId(rawValue: "smithy.example#String"))
    }
}

