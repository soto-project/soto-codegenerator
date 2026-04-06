//===----------------------------------------------------------------------===//
//
// This source file is part of the Soto for AWS open source project
//
// Copyright (c) 2026 the Soto project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Soto project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation

enum DownloaderError: Error, CustomStringConvertible {
    case invalidURL(String)
    case failedToLoad(String)
    case failedToDecode(String, Error)
    case failedToBase64Decode(String)
    case failedToFindService(String)
    case failedToWriteFile(String)

    var description: String {
        switch self {
        case .invalidURL(let url): "Invalid URL \(url)"
        case .failedToLoad(let url): "Failed to load \(url)"
        case .failedToDecode(let decoding, let error): "Failed to decode \(decoding). Error: \(error)"
        case .failedToBase64Decode(let url): "Failed to baset64 decode \(url)."
        case .failedToFindService(let service): "Failed to find service \(service) in API files"
        case .failedToWriteFile(let file): "Failed to write to \(file)"
        }
    }
}
