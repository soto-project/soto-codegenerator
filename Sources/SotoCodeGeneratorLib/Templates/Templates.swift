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

import Mustache

enum Templates {
    static var values: [String: String] = [
        "api": apiTemplate,
        "comment": commentTemplate,
        "enum": enumTemplate,
        "enumWithValues": enumWithValuesTemplate,
        "errors": errorTemplate,
        "header": headerTemplate,
        "paginators": paginatorTemplate,
        "shapes": shapesTemplate,
        "struct": structTemplate,
        "waiters": waiterTemplate,
    ]

    static func createLibrary() throws -> MustacheLibrary {
        var library = MustacheLibrary()
        for v in self.values {
            let template = try MustacheTemplate(string: v.value)
            library.register(template, named: v.key)
        }
        return library
    }
}
