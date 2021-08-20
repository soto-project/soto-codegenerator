//
//  File.swift
//  File
//
//  Created by Adam Fowler on 20/08/2021.
//

import HummingbirdMustache

enum Templates {
    static var values: [String: String] = [
        "api": apiTemplate,
        "api+async": apiAsyncTemplate,
        "enum": enumTemplate,
        "enumWithValues": enumWithValuesTemplate,
        "error": errorTemplate,
        "header": headerTemplate,
        "paginator": paginatorTemplate,
        "paginator+async": paginatorAsyncTemplate,
        "shapes": shapesTemplate,
        "struct": structTemplate,
        "waiter": waiterTemplate,
        "waiter+async": waiterAsyncTemplate
    ]
    
    static func createLibrary() throws -> HBMustacheLibrary {
        let library = HBMustacheLibrary()
        for v in values {
            let template = try HBMustacheTemplate(string: v.value)
            library.register(template, named: v.key)
        }
        return library
    }
}
