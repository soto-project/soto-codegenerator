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

#if os(Linux)
import FoundationNetworking
#endif

struct GitHubAPI {
    let ghToken: String?

    func downloadRawFile(path: String) async throws(DownloaderError) -> Data {
        let url = URL(string: "https://raw.githubusercontent.com\(path)")!
        let contents: Data
        let response: URLResponse
        do {
            let request = URLRequest(url: url)
            (contents, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw .failedToLoad(url.absoluteString)
        }
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw DownloaderError.failedToLoad(url.absoluteString)
        }
        return contents
    }

    func callGitHubAPI(path: String) async throws(DownloaderError) -> Data {
        let url = URL(string: "https://api.github.com\(path)")!
        return try await callGitHubAPI(url: url)
    }

    func callGitHubAPI(url: URL) async throws(DownloaderError) -> Data {
        let contents: Data
        let response: URLResponse
        do {
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
            if let ghToken {
                request.setValue("Bearer \(ghToken)", forHTTPHeaderField: "Authorization")
            }
            (contents, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw .failedToLoad(url.absoluteString)
        }
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw DownloaderError.failedToLoad(url.absoluteString)
        }
        return contents
    }
}
