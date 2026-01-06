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
import AsyncHTTPClient
import NIOHTTP1
/// Downloads file from GitHub repositories.
struct GitHubResource {
    
    /// Defines errors specific to GitHub resource operations.
    enum GitHubResourceError: Error, CustomDebugStringConvertible {
        case invalidURL
        case missingURLComponents
        case invalidGitHubResponse
        
        var debugDescription: String {
            switch self {
            case .invalidURL:
                return "The provided URL is invalid."
            case .missingURLComponents:
                return "The URL is missing necessary components."
            case .invalidGitHubResponse:
                return "Received an invalid response from GitHub."
            }
        }
    }
    
    /// The input folder containing the GitHub repository URL.
    var inputFolder: String
    
    /// The output folder where the downloaded files will be saved.
    var outputFolder: String
    
    /// An array of expected services to be downloaded.
    var modelFilter: [String] = []
    
    /// The base URL for the GitHub API.
    static var gitHubApi: URL { URL(string:  "https://api.github.com/repos")! }
    
    /// trigger Downloading files from the GitHub repository.
    func download() async throws {
        
        // Ensure that the input folder contains a valid GitHub repository URL.
        guard inputFolder.contains("github.com") else { throw GitHubResourceError.invalidURL }
        guard let gitHubURL = URL(string: inputFolder) else { throw GitHubResourceError.invalidURL }
        
        // Extract user, repository, directory, and reference components from the GitHub URL.
        let (user, repository, directory, reference) = try extractGitHubComponents(from: gitHubURL.absoluteString)
        
        // Fetch the list of files from the GitHub repository.
        let files = try await fetchGitHubTree(user: user, repository: repository, directory: directory)
        
        // Create the output folder if it does not exist.
        var isDirectory = ObjCBool(false)
        let exists = FileManager.default.fileExists(atPath: outputFolder, isDirectory: &isDirectory)
        if !(exists && isDirectory.boolValue) {
            try FileManager.default.createDirectory(atPath: outputFolder, withIntermediateDirectories: true)
        }
        
        // Download files concurrently using a task group.
        try await withThrowingTaskGroup(of: Void.self) { group in
            for filePath in files {
                group.addTask {
                    let escapedPath = filePath.replacingOccurrences(of: "#", with: "%23")
                    let downloadPath = [user, repository, reference, escapedPath].joined(separator: "/")
                    if let fileName = escapedPath.components(separatedBy: "/").last {
                        print("Downloading: \(fileName)")
                    }
                    try await downloadFile(at: downloadPath, to: escapedPath)
                }
            }
            try await group.waitForAll()
        }
    }
    
    /// Fetches the list of files from the GitHub repository using the GitHub Trees API.
    private func fetchGitHubTree(user: String, repository: String, directory: String) async throws -> [String] {
        
        let directoryName = directory.components(separatedBy: "/").last ?? ""
        var requestURLString = GitHubResource.gitHubApi.absoluteString
        requestURLString.append("/\(user)/\(repository)/git/trees/HEAD?recursive=1")
        
        var httpRequest = try HTTPClient.Request(url: requestURLString)
        httpRequest.headers.add(name: "User-Agent", value: "AsyncHttpClient")
        let response = try await HTTPClient.shared.execute(request: httpRequest).get()
        guard response.status == .ok, let data = response.body else { throw GitHubResourceError.invalidGitHubResponse }
        
        let gitHubDirectoryTree = try JSONDecoder().decode(GitHubDirectoryTree.self, from: data)
        
        var filePaths = [String]()
        for item in gitHubDirectoryTree.tree {
            let serviceName = (item.path.components(separatedBy: "/").last?.components(separatedBy: ".").first) ?? ""
            if !modelFilter.isEmpty, !modelFilter.contains(serviceName) {
                continue
            }
            // Check for subdirectory
            let currentDirectory = item.path.components(separatedBy: "/").dropLast().last ?? ""
            if item.type == "blob" && currentDirectory.elementsEqual(directoryName) {
                filePaths.append(item.path)
            }
        }
        
        return filePaths
    }
    
    /// Extracts user, repository, directory, and reference components from the GitHub repository URL.
     private func extractGitHubComponents(from urlString: String) throws -> (user: String, repository: String, directory: String, reference: String) {
         guard let url = URL(string: urlString),
               url.host == "github.com",
               let pathComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)?.path.components(separatedBy: "/").dropFirst(1).map({ $0 })
         else {
             throw GitHubResourceError.invalidURL
         }
         
         guard pathComponents.count > 4 else { throw GitHubResourceError.missingURLComponents }
         
         let user = pathComponents[0]
         let repository = pathComponents[1]
         let reference = pathComponents[3]
         let directory = pathComponents[4...].joined(separator: "/")
         
         return (user, repository, directory, reference)
     }
    
    /// Downloads a raw file from the GitHub repository.
    private func downloadFile(at path: String, to directory: String) async throws {
        let client = HTTPClient(eventLoopGroupProvider: .singleton)
        
        let downloadUrlString = "https://raw.githubusercontent.com/" + path
        let downloadRequest = try HTTPClient.Request(url: downloadUrlString)
        let fileName = directory.components(separatedBy: "/").last ?? directory
        let filePath = outputFolder + "/\(fileName)"
        
        var downloadStatus: HTTPResponseStatus = .noContent
        let delegate = try FileDownloadDelegate(path: filePath) { _, response in
            downloadStatus = response.status
        }
        
        _ = try await client.execute(request: downloadRequest, delegate: delegate).get()
        
        guard downloadStatus == .ok else { throw GitHubResourceError.invalidGitHubResponse }
        
        try await client.shutdown()
    }
}


