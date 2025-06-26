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
import Foundation
/// Represents the structure of a GitHub directory tree
struct GitHubDirectoryTree: Decodable {
    
    /// Represents the content within the GitHub directory tree.
    struct Content: Decodable {
        var type: String
        let url: URL
        let size: Int?
        let path: String
    }
    
    let tree: [Content]
}
