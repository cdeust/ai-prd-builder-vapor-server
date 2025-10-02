import Foundation
import Domain
import Application  // For GitHubParserPort protocol
import ImplementationAnalysis  // For GitHubFileNode, GitHubFileType
import AsyncHTTPClient
import NIOCore


// MARK: - GitHub Tree Parser

/// Parses GitHub repository structure using GitHub API
public final class GitHubTreeParser: GitHubParserPort, Sendable {
    private let httpClient: HTTPClient
    private let baseURL: String = "https://api.github.com"

    public init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    /// Fetch repository file tree recursively
    /// - Parameters:
    ///   - owner: Repository owner (username or organization)
    ///   - repo: Repository name
    ///   - branch: Branch name (default: main)
    ///   - accessToken: Optional GitHub access token for private repos
    /// - Returns: Array of file nodes
    public func fetchFileTree(
        owner: String,
        repo: String,
        branch: String = "main",
        accessToken: String? = nil
    ) async throws -> [GitHubFileNode] {
        // 1. Get the SHA of the latest commit on the branch
        let branchSha = try await fetchBranchSha(
            owner: owner,
            repo: repo,
            branch: branch,
            accessToken: accessToken
        )

        // 2. Fetch the tree recursively
        let tree = try await fetchTree(
            owner: owner,
            repo: repo,
            treeSha: branchSha,
            recursive: true,
            accessToken: accessToken
        )

        // 3. Filter for files only (exclude directories) and map to GitHubFileNode
        return tree.tree
            .filter { $0.type == "blob" }
            .map { node in
                GitHubFileNode(
                    path: node.path,
                    mode: node.mode,
                    type: node.type == "blob" ? .blob : .tree,
                    sha: node.sha,
                    size: node.size,
                    url: node.url
                )
            }
    }

    /// Fetch repository information (languages, stars, etc.)
    public func fetchRepositoryInfo(
        owner: String,
        repo: String,
        accessToken: String? = nil
    ) async throws -> Application.GitHubRepositoryInfo {
        var request = HTTPClientRequest(url: "\(baseURL)/repos/\(owner)/\(repo)")
        request.method = .GET
        request.headers.add(name: "Accept", value: "application/vnd.github.v3+json")
        request.headers.add(name: "User-Agent", value: "ai-prd-builder-vapor/1.0")
        if let token = accessToken {
            request.headers.add(name: "Authorization", value: "Bearer \(token)")
        }

        let response = try await httpClient.execute(request, timeout: .seconds(30))

        guard response.status == .ok else {
            let errorBody = try await response.body.collect(upTo: 1024 * 1024)
            let errorMessage = String(buffer: errorBody)
            throw GitHubError.apiError(
                statusCode: response.status.code,
                message: "Failed to fetch repository info: \(errorMessage)"
            )
        }

        let responseBody = try await response.body.collect(upTo: 10 * 1024 * 1024)
        let fullInfo = try JSONDecoder().decode(GitHubRepositoryInfoFull.self, from: responseBody)

        // Map to the simpler Application layer model
        return Application.GitHubRepositoryInfo(
            fullName: fullInfo.fullName,
            description: fullInfo.description
        )
    }

    /// Fetch language statistics for repository
    public func fetchLanguages(
        owner: String,
        repo: String,
        accessToken: String? = nil
    ) async throws -> [String: Int] {
        var request = HTTPClientRequest(url: "\(baseURL)/repos/\(owner)/\(repo)/languages")
        request.method = .GET
        request.headers.add(name: "Accept", value: "application/vnd.github.v3+json")
        request.headers.add(name: "User-Agent", value: "ai-prd-builder-vapor/1.0")
        if let token = accessToken {
            request.headers.add(name: "Authorization", value: "Bearer \(token)")
        }

        let response = try await httpClient.execute(request, timeout: .seconds(30))

        guard response.status == .ok else {
            let errorBody = try await response.body.collect(upTo: 1024 * 1024)
            let errorMessage = String(buffer: errorBody)
            throw GitHubError.apiError(
                statusCode: response.status.code,
                message: "Failed to fetch languages: \(errorMessage)"
            )
        }

        let responseBody = try await response.body.collect(upTo: 10 * 1024 * 1024)
        return try JSONDecoder().decode([String: Int].self, from: responseBody)
    }

    /// Fetch file content from GitHub
    public func fetchFileContent(
        owner: String,
        repo: String,
        path: String,
        ref: String = "main",
        accessToken: String? = nil
    ) async throws -> String {
        var request = HTTPClientRequest(url: "\(baseURL)/repos/\(owner)/\(repo)/contents/\(path)?ref=\(ref)")
        request.method = .GET
        request.headers.add(name: "Accept", value: "application/vnd.github.v3+json")
        request.headers.add(name: "User-Agent", value: "ai-prd-builder-vapor/1.0")
        if let token = accessToken {
            request.headers.add(name: "Authorization", value: "Bearer \(token)")
        }

        let response = try await httpClient.execute(request, timeout: .seconds(30))

        guard response.status == .ok else {
            throw GitHubError.fileNotFound(path: path)
        }

        let responseBody = try await response.body.collect(upTo: 10 * 1024 * 1024)
        let fileResponse = try JSONDecoder().decode(GitHubFileContentResponse.self, from: responseBody)

        // Decode Base64 content
        guard let content = fileResponse.decodedContent else {
            throw GitHubError.invalidContent(path: path)
        }

        return content
    }

    /// Batch fetch file contents (parallel requests)
    public func batchFetchFileContents(
        owner: String,
        repo: String,
        paths: [String],
        ref: String = "main",
        accessToken: String? = nil
    ) async throws -> [String: String] {
        var results: [String: String] = [:]

        // Process in batches to avoid rate limiting
        let batchSize = 10
        for batch in paths.chunked(into: batchSize) {
            // Fetch all files in batch concurrently
            await withTaskGroup(of: (String, Result<String, Error>).self) { group in
                for path in batch {
                    group.addTask { @Sendable in
                        do {
                            let content = try await self.fetchFileContent(
                                owner: owner,
                                repo: repo,
                                path: path,
                                ref: ref,
                                accessToken: accessToken
                            )
                            return (path, .success(content))
                        } catch {
                            return (path, .failure(error))
                        }
                    }
                }

                for await (path, result) in group {
                    switch result {
                    case .success(let content):
                        results[path] = content
                    case .failure(let error):
                        print("⚠️ Failed to fetch \(path): \(error)")
                    }
                }
            }

            // Rate limiting: wait between batches
            if !batch.isEmpty {
                try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds
            }
        }

        return results
    }

    // MARK: - Private Methods

    private func fetchBranchSha(
        owner: String,
        repo: String,
        branch: String,
        accessToken: String?
    ) async throws -> String {
        var request = HTTPClientRequest(url: "\(baseURL)/repos/\(owner)/\(repo)/branches/\(branch)")
        request.method = .GET
        request.headers.add(name: "Accept", value: "application/vnd.github.v3+json")
        request.headers.add(name: "User-Agent", value: "ai-prd-builder-vapor/1.0")
        if let token = accessToken {
            request.headers.add(name: "Authorization", value: "Bearer \(token)")
        }

        let response = try await httpClient.execute(request, timeout: .seconds(30))

        guard response.status == .ok else {
            let errorBody = try await response.body.collect(upTo: 1024 * 1024)
            let errorMessage = String(buffer: errorBody)
            throw GitHubError.apiError(
                statusCode: response.status.code,
                message: "Failed to fetch branch '\(branch)': \(errorMessage)"
            )
        }

        let responseBody = try await response.body.collect(upTo: 10 * 1024 * 1024)
        let branchResponse = try JSONDecoder().decode(GitHubBranchResponse.self, from: responseBody)
        return branchResponse.commit.sha
    }

    private func fetchTree(
        owner: String,
        repo: String,
        treeSha: String,
        recursive: Bool,
        accessToken: String?
    ) async throws -> GitHubTreeResponse {
        let recursiveParam = recursive ? "?recursive=1" : ""
        var request = HTTPClientRequest(url: "\(baseURL)/repos/\(owner)/\(repo)/git/trees/\(treeSha)\(recursiveParam)")
        request.method = .GET
        request.headers.add(name: "Accept", value: "application/vnd.github.v3+json")
        request.headers.add(name: "User-Agent", value: "ai-prd-builder-vapor/1.0")
        if let token = accessToken {
            request.headers.add(name: "Authorization", value: "Bearer \(token)")
        }

        let response = try await httpClient.execute(request, timeout: .seconds(30))

        guard response.status == .ok else {
            let errorBody = try await response.body.collect(upTo: 1024 * 1024)
            let errorMessage = String(buffer: errorBody)
            throw GitHubError.apiError(
                statusCode: response.status.code,
                message: "Failed to fetch tree: \(errorMessage)"
            )
        }

        let responseBody = try await response.body.collect(upTo: 10 * 1024 * 1024)
        return try JSONDecoder().decode(GitHubTreeResponse.self, from: responseBody)
    }
}

// MARK: - GitHub API Response Models

struct GitHubBranchResponse: Codable {
    let name: String
    let commit: GitHubCommit

    struct GitHubCommit: Codable {
        let sha: String
        let url: String
    }
}

struct GitHubTreeResponse: Codable {
    let sha: String
    let url: String
    let tree: [GitHubTreeNode]
    let truncated: Bool

    struct GitHubTreeNode: Codable {
        let path: String
        let mode: String
        let type: String
        let sha: String
        let size: Int?
        let url: String

        func toFileNode() -> GitHubFileNode? {
            guard let fileType = GitHubFileType(rawValue: type) else { return nil }

            return GitHubFileNode(
                path: path,
                mode: mode,
                type: fileType,
                sha: sha,
                size: size,
                url: url
            )
        }
    }
}

extension GitHubTreeResponse.GitHubTreeNode {
    var asFileNode: GitHubFileNode? {
        guard let fileType = GitHubFileType(rawValue: type) else { return nil }
        return GitHubFileNode(
            path: path,
            mode: mode,
            type: fileType,
            sha: sha,
            size: size,
            url: url
        )
    }
}

// NOTE: GitHubFileNode and GitHubFileType are now imported from ImplementationAnalysis library
// This ensures consistency and avoids duplication across the codebase

struct GitHubFileContentResponse: Codable {
    let name: String
    let path: String
    let sha: String
    let size: Int
    let url: String
    let content: String  // Base64 encoded
    let encoding: String

    var decodedContent: String? {
        guard encoding == "base64" else { return nil }

        // Remove newlines and decode
        let cleaned = content.replacingOccurrences(of: "\n", with: "")
        guard let data = Data(base64Encoded: cleaned) else { return nil }

        return String(data: data, encoding: .utf8)
    }
}

public struct GitHubRepositoryInfoFull: Codable {
    public let id: Int
    public let name: String
    public let fullName: String
    public let description: String?
    public let htmlUrl: String
    public let language: String?
    public let stargazersCount: Int
    public let forksCount: Int
    public let openIssuesCount: Int
    public let defaultBranch: String
    public let createdAt: Date
    public let updatedAt: Date
    public let size: Int  // KB

    enum CodingKeys: String, CodingKey {
        case id, name, description, language, size
        case fullName = "full_name"
        case htmlUrl = "html_url"
        case stargazersCount = "stargazers_count"
        case forksCount = "forks_count"
        case openIssuesCount = "open_issues_count"
        case defaultBranch = "default_branch"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - GitHub Errors

public enum GitHubError: Error, CustomStringConvertible {
    case branchNotFound(branch: String)
    case fileNotFound(path: String)
    case invalidContent(path: String)
    case apiError(statusCode: UInt, message: String)
    case rateLimitExceeded
    case unauthorized

    public var description: String {
        switch self {
        case .branchNotFound(let branch):
            return "Branch '\(branch)' not found"
        case .fileNotFound(let path):
            return "File '\(path)' not found"
        case .invalidContent(let path):
            return "Invalid content for file '\(path)'"
        case .apiError(let statusCode, let message):
            return "GitHub API error (\(statusCode)): \(message)"
        case .rateLimitExceeded:
            return "GitHub API rate limit exceeded"
        case .unauthorized:
            return "Unauthorized: Invalid or missing access token"
        }
    }
}

// MARK: - Repository URL Parser

public struct GitHubRepositoryURL {
    public let owner: String
    public let repo: String

    /// Parse GitHub URL to extract owner and repo
    /// Supports:
    /// - https://github.com/owner/repo
    /// - https://github.com/owner/repo.git
    /// - git@github.com:owner/repo.git
    public static func parse(_ url: String) -> GitHubRepositoryURL? {
        // HTTPS URLs
        if url.contains("github.com/") {
            let pattern = #"github\.com[:/]([^/]+)/([^/.]+)"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
            let range = NSRange(url.startIndex..., in: url)

            guard let match = regex.firstMatch(in: url, range: range),
                  match.numberOfRanges == 3 else {
                return nil
            }

            let ownerRange = Range(match.range(at: 1), in: url)!
            let repoRange = Range(match.range(at: 2), in: url)!

            let owner = String(url[ownerRange])
            let repo = String(url[repoRange])

            return GitHubRepositoryURL(owner: owner, repo: repo)
        }

        return nil
    }
}

// MARK: - Helper Extensions

extension Array {
    /// Split array into chunks of specified size
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
