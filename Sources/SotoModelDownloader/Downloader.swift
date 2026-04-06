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

@available(macOS 13, *)
struct Downloader {
    let directory: GitHubTree
    let ghAPI: GitHubAPI

    static func setup(
        ghToken: String?
    ) async throws(DownloaderError) -> Downloader {
        let ghAPI = GitHubAPI(ghToken: ghToken)
        /// Get git commit hash from soto and download models using that hash
        let hash = try await getModelHash(path: "/soto-project/soto/refs/heads/main/.aws-model-hash", ghAPI: ghAPI)
        let directory = try await getAPIModelsAWS(hash: hash, ghAPI: ghAPI)
        return .init(directory: directory, ghAPI: ghAPI)
    }

    /// Get current git hash for models used by Soto
    static func getModelHash(path: String, ghAPI: GitHubAPI) async throws(DownloaderError) -> String {
        let file = try await ghAPI.downloadRawFile(path: path)
        return String(decoding: file, as: UTF8.self).filter { !$0.isNewline && !$0.isWhitespace }
    }

    /// Get api-models-aws tree
    static func getAPIModelsAWS(hash: String, ghAPI: GitHubAPI) async throws(DownloaderError) -> GitHubTree {
        // get https://github.com/aws/api-models-aws.git tree
        let data = try await ghAPI.callGitHubAPI(path: "/repos/aws/api-models-aws/git/trees/\(hash)?recursive=1")
        do {
            return try JSONDecoder().decode(GitHubTree.self, from: data)
        } catch {
            throw .failedToDecode("GitHub trees response", error)
        }
    }

    /// Get GitHub resource, using URL from tree output
    private func getGitHubResource(url: URL) async throws(DownloaderError) -> String {
        do {
            let data = try await self.ghAPI.callGitHubAPI(url: url)
            let resource: GitHubResource
            do {
                resource = try JSONDecoder().decode(GitHubResource.self, from: data)
            } catch {
                throw .failedToDecode("GitHub trees response", error)
            }
            let encodedContent = resource.content.filter { !$0.isNewline && !$0.isWhitespace }
            guard let content = Data(base64Encoded: encodedContent) else {
                throw .failedToBase64Decode(url.absoluteString)
            }
            return String(decoding: content, as: UTF8.self)
        }
    }

    func writeServiceFile(_ service: String, to folder: String) async throws(DownloaderError) {
        guard let entry = directory.tree.first(where: { $0.path.hasPrefix("models/\(service)/") && $0.path.hasSuffix(".json") }) else {
            throw .failedToFindService(service)
        }
        let fileContents = try await getGitHubResource(url: entry.url)
        let target = URL(fileURLWithPath: folder).appending(path: "\(service).json")
        do {
            try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
            print("Writing: \(target.relativePath)")
            try fileContents.write(to: target, atomically: true, encoding: .utf8)
        } catch {
            throw .failedToWriteFile(target.absoluteString)
        }
    }

    func writeEndpoints(to folder: String) async throws(DownloaderError) {
        let endpoints = try await self.ghAPI.downloadRawFile(
            path:
                "/aws/aws-sdk-go-v2/refs/heads/main/codegen/smithy-aws-go-codegen/src/main/resources/software/amazon/smithy/aws/go/codegen/endpoints.json"
        )
        let target = URL(fileURLWithPath: folder).appending(path: "endpoints.json")
        do {
            print("Writing: \(target.relativePath)")
            try endpoints.write(to: target)
        } catch {
            throw .failedToWriteFile(target.absoluteString)
        }
    }

    func loadConfig(path: String) async throws(DownloaderError) -> ConfigFile {
        let file: Data
        do {
            file = try Data(contentsOf: URL(fileURLWithPath: path))
        } catch {
            throw .failedToLoad(path)
        }
        do {
            return try JSONDecoder().decode(ConfigFile.self, from: file)
        } catch {
            throw .failedToDecode(path, error)
        }
    }
}
