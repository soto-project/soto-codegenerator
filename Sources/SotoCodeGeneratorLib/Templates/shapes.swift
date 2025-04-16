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

extension Templates {
    static let shapesTemplate = """
        {{%CONTENT_TYPE:TEXT}}
        {{>header}}

        #if canImport(FoundationEssentials)
        import FoundationEssentials
        #else
        import Foundation
        #endif
        @_spi(SotoInternal) import SotoCore

        extension {{name}} {
            // MARK: Enums
        {{#shapes}}
        {{#enum}}

        {{>enum}}
        {{/enum}}
        {{/shapes}}
        {{#shapes}}
        {{#enumWithValues}}

        {{>enumWithValues}}
        {{/enumWithValues}}
        {{/shapes}}

            // MARK: Shapes
        {{#shapes}}
        {{#struct}}

        {{>struct}}
        {{/struct}}
        {{/shapes}}
        }
        {{#errors}}

        {{>errors}}
        {{/errors}}
        {{#extraCode}}

        {{.}}
        {{/extraCode}}
        """
}
