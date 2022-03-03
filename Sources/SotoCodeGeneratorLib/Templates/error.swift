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

extension Templates {
    static let errorTemplate = #"""
    {{%CONTENT_TYPE:TEXT}}
    {{>header}}

    import SotoCore

    /// Error enum for {{name}}
    public struct {{errorName}}: AWSErrorType {
        enum Code: String {
    {{#errors}}
            case {{enum}} = "{{string}}"
    {{/errors}}
        }

        private let error: Code
        public let context: AWSErrorContext?

        /// initialize {{name}}
        public init?(errorCode: String, context: AWSErrorContext) {
            guard let error = Code(rawValue: errorCode) else { return nil }
            self.error = error
            self.context = context
        }

        internal init(_ error: Code) {
            self.error = error
            self.context = nil
        }

        /// return error code string
        public var errorCode: String { self.error.rawValue }

    {{#errors}}
    {{#comment}}
        /// {{.}}
    {{/comment}}
        public static var {{enum}}: Self { .init(.{{enum}}) }
    {{/errors}}
    }

    extension {{errorName}}: Equatable {
        public static func == (lhs: {{errorName}}, rhs: {{errorName}}) -> Bool {
            lhs.error == rhs.error
        }
    }

    extension {{errorName}}: CustomStringConvertible {
        public var description: String {
            return "\(self.error.rawValue): \(self.message ?? "")"
        }
    }
    """#
}
