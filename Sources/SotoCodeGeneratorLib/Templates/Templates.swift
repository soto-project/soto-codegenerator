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

import HummingbirdMustache

enum Templates {
    static var values: [String: String] = [
        "api": apiTemplate,
        "api_async": apiAsyncTemplate,
        "comment": commentTemplate,
        "enum": enumTemplate,
        "enumWithValues": enumWithValuesTemplate,
        "errors": errorTemplate,
        "header": headerTemplate,
        "paginators": paginatorTemplate,
        "paginators_async": paginatorAsyncTemplate,
        "shapes": shapesTemplate,
        "struct": structTemplate,
        "waiters": waiterTemplate,
        "waiters_async": waiterAsyncTemplate
    ]

    static func createLibrary() throws -> HBMustacheLibrary {
        let library = HBMustacheLibrary()
        for v in self.values {
            let template = try HBMustacheTemplate(string: v.value)
            library.register(template, named: v.key)
        }
        return library
    }
}
