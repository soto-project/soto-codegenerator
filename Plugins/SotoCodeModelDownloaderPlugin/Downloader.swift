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
/// Downloads file from GitHub repositories.
struct GitHubResource {
    
    /// The input folder containing the GitHub repository URL.
    var inputFolder: String
    
    /// The output folder where the downloaded files will be saved.
    var outputFolder: String
    
    /// An array of expected services to be downloaded.
    var expectedServices: [String] = []
    
    /// The base URL for the GitHub API.
    static var gitApi: URL { URL(string:  "https://api.github.com/repos")! }
    
    /// trigger Downloading files from the GitHub repository.
    func download() async throws {
        
        // Ensure that the input folder contains a GitHub repository URL.
        guard inputFolder.contains("github.com") else { return }
        guard let gitFolderUrl = URL(string: inputFolder) else { return }
        guard let (user, repo, directory, ref) = try extractGitComponents(from: gitFolderUrl.absoluteString) else { return }
        
        // Fetch the list of files from the GitHub repository.
        let files = try await gitTreesApi(user: user, repository: repo, directory: directory)
        
        // Create the output folder if it does not exist.
        if !FileManager.default.fileExists(atPath: outputFolder)   {
            try FileManager.default.createDirectory(atPath: outputFolder, withIntermediateDirectories: true)
        }
        
        // Download files concurrently using a task group.
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<files.count {
                group.addTask {
                    if let filepath = files[index] as? String {
                        let escapingPath = filepath.replacingOccurrences(of: "#", with: "%23")
                        let path = [user, repo, ref, escapingPath].joined(separator: "/")
                        if let name = escapingPath.components(separatedBy: "/").last {
                            print("Downloading: " + name)
                        }
                        try await fetchFileWith(path: path, directory: escapingPath)
                    }
                }
            }
            try await group.waitForAll()
        }
    }
    
    /// Fetches the list of files from the GitHub repository using the GitHub Trees API.
    private func gitTreesApi(user: String, repository: String, directory: String) async throws -> [Any] {
        
        let directory = directory.components(separatedBy: "/").last ?? ""
        var requestUrlString = GitHubResource.gitApi.absoluteString
        requestUrlString.append("/\(user)/\(repository)/git/trees/HEAD?recursive=1")
        guard let requestUrl = URL(string: requestUrlString) else { return [] }
        
        let (data, _) = try await URLSession.shared.data(from: requestUrl)
        
        let contents = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let tree = contents?["tree"] as? [Any] else { return [] }
        var filePaths = [String]()
        for item in tree {
            guard let item = item as? [String: Any] else { continue }
            let type = (item["type"] as? String) ?? ""
            let path = (item["path"] as? String) ?? ""
            let serviceName = (path.components(separatedBy: "/")
                .last?.components(separatedBy: ".").first) ?? ""
            if !expectedServices.isEmpty , !expectedServices.contains(serviceName) {
                continue
            }
            // Check for subdirectory
            let currentDirectory = path.components(separatedBy: "/").dropLast().last ?? ""
            if (type == "blob" && currentDirectory.elementsEqual(directory)){
                filePaths.append(path);
            }
        }
        return filePaths
    }
    
    /// Extracts user, repository, directory, and reference from the GitHub repository URL.
    private func extractGitComponents(from url: String) throws -> (user: String, repo: String, directory: String, ref: String)? {
        let pattern = #"github\.com\/([^\/]+)\/([^\/]+)\/(?:tree|blob)\/([^\/]+)\/(.*)"#
        
        let regex = try NSRegularExpression(pattern: pattern, options: [])
        
        guard let match = regex.firstMatch(in: url, options: [], range: NSRange(location: 0, length: url.utf16.count)) else {
            return nil
        }
        
        let nsUrl = url as NSString
        let userRange = match.range(at: 1)
        let repoRange = match.range(at: 2)
        let refRange = match.range(at: 3)
        let directoryRange = match.range(at: 4)
        
        let user = nsUrl.substring(with: userRange)
        let repo = nsUrl.substring(with: repoRange)
        let ref = nsUrl.substring(with: refRange)
        let directory = nsUrl.substring(with: directoryRange)
        
        return (user, repo, directory, ref)
    }
    
    /// Downloads raw file from the GitHub repository.
    private func fetchFileWith(path: String, directory: String) async throws {
        guard let downloadURL = URL(string: "https://raw.githubusercontent.com/" + path) else { return }
        
        let (data, _) = try await URLSession.shared.data(from: downloadURL)
        
        let fileName = directory.components(separatedBy: "/").last ?? directory
        let filePath = outputFolder + "/\(fileName)"
        
        FileManager.default.createFile(atPath: filePath, contents: data)
    }
}

// MARK: - Model and Endpoint URLs -

enum Repo {
    /// Model files github directory.
    static let modelDirectory = "https://github.com/soto-project/soto/tree/c36f311add37d4868b6b1688d88d320a5626d6ef/models"
    
    /// Endpoints github directory.
    static let endpointsDirectory = "https://github.com/soto-project/soto/tree/c36f311add37d4868b6b1688d88d320a5626d6ef/models/endpoints"
}
