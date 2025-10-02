import Foundation
import Domain
import ImplementationAnalysis

// MARK: - Port for GitHub Parsing (should move to Domain layer eventually)
public protocol GitHubParserPort: Sendable {
    func fetchFileTree(owner: String, repo: String, branch: String, accessToken: String?) async throws -> [GitHubFileNode]
    func fetchRepositoryInfo(owner: String, repo: String, accessToken: String?) async throws -> GitHubRepositoryInfo
    func fetchLanguages(owner: String, repo: String, accessToken: String?) async throws -> [String: Int]
    func batchFetchFileContents(owner: String, repo: String, paths: [String], ref: String, accessToken: String?) async throws -> [String: String]
}

// GitHub repository info model
public struct GitHubRepositoryInfo: Sendable {
    public let fullName: String
    public let description: String?

    public init(fullName: String, description: String?) {
        self.fullName = fullName
        self.description = description
    }
}

// MARK: - GitHub URL Parser
public struct GitHubURL {
    public let owner: String
    public let repo: String

    public static func parse(_ urlString: String) -> GitHubURL? {
        // HTTPS URLs: https://github.com/owner/repo or https://github.com/owner/repo.git
        if urlString.contains("github.com/") {
            let pattern = #"github\.com[:/]([^/]+)/([^/.]+)"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
            let range = NSRange(urlString.startIndex..., in: urlString)

            guard let match = regex.firstMatch(in: urlString, range: range),
                  match.numberOfRanges == 3 else {
                return nil
            }

            let ownerRange = Range(match.range(at: 1), in: urlString)!
            let repoRange = Range(match.range(at: 2), in: urlString)!

            let owner = String(urlString[ownerRange])
            let repo = String(urlString[repoRange])

            return GitHubURL(owner: owner, repo: repo)
        }

        return nil
    }
}

/// Use case for indexing a GitHub repository
/// Orchestrates fetching repository tree, building Merkle tree, and creating codebase project
public final class IndexGitHubUseCase: @unchecked Sendable {
    private let codebaseRepository: CodebaseRepositoryProtocol
    private let githubParser: GitHubParserPort
    private let embeddingGenerator: EmbeddingGeneratorPort

    public init(
        codebaseRepository: CodebaseRepositoryProtocol,
        githubParser: GitHubParserPort,
        embeddingGenerator: EmbeddingGeneratorPort
    ) {
        self.codebaseRepository = codebaseRepository
        self.githubParser = githubParser
        self.embeddingGenerator = embeddingGenerator
    }

    public func execute(_ input: Input) async throws -> Output {
        // Parse GitHub URL
        guard let repoURL = GitHubURL.parse(input.repositoryUrl) else {
            throw IndexGitHubError.invalidRepositoryUrl(input.repositoryUrl)
        }

        // Check if this repository is already indexed
        if let existingProject = try await codebaseRepository.findProjectByRepository(
            url: input.repositoryUrl,
            branch: input.branch
        ) {
            // Return existing project instead of creating duplicate
            return Output(
                codebaseId: existingProject.id,
                repositoryUrl: input.repositoryUrl,
                branch: input.branch,
                totalFiles: existingProject.totalFiles,
                merkleRootHash: existingProject.merkleRootHash ?? "",
                indexingStatus: existingProject.indexingStatus.rawValue
            )
        }

        // Fetch repository tree
        let fileNodes = try await githubParser.fetchFileTree(
            owner: repoURL.owner,
            repo: repoURL.repo,
            branch: input.branch,
            accessToken: input.accessToken
        )

        // Fetch repository metadata (languages from GitHub API)
        let languages = try await githubParser.fetchLanguages(
            owner: repoURL.owner,
            repo: repoURL.repo,
            accessToken: input.accessToken
        )

        // Build Merkle tree
        let merkleTree = MerkleTree.build(from: fileNodes)

        // Create codebase project - AI will analyze files on-demand during PRD generation
        let codebase = CodebaseProject(
            id: UUID(),
            repositoryUrl: input.repositoryUrl,
            repositoryBranch: input.branch,
            repositoryType: .github,
            merkleRootHash: merkleTree.rootHash,
            totalFiles: fileNodes.count,
            indexingStatus: .pending,
            detectedLanguages: languages,
            detectedFrameworks: [], // Let AI infer from actual files
            architecturePatterns: [], // Let AI infer from actual code structure
            createdAt: Date(),
            updatedAt: Date()
        )

        let savedCodebase = try await codebaseRepository.saveProject(codebase)

        // Save Merkle root hash
        try await codebaseRepository.saveMerkleRoot(
            projectId: savedCodebase.id,
            rootHash: merkleTree.rootHash
        )

        // TODO: Queue background indexing job to:
        // 1. Parse files and create chunks
        // 2. Generate embeddings
        // 3. Update indexing status

        return Output(
            codebaseId: savedCodebase.id,
            repositoryUrl: input.repositoryUrl,
            branch: input.branch,
            totalFiles: fileNodes.count,
            merkleRootHash: merkleTree.rootHash,
            indexingStatus: "pending"
        )
    }

}

// MARK: - Input/Output Types

extension IndexGitHubUseCase {
    public struct Input {
        public let repositoryUrl: String
        public let branch: String
        public let accessToken: String?
        public let userId: UUID

        public init(
            repositoryUrl: String,
            branch: String = "main",
            accessToken: String? = nil,
            userId: UUID
        ) {
            self.repositoryUrl = repositoryUrl
            self.branch = branch
            self.accessToken = accessToken
            self.userId = userId
        }
    }

    public struct Output {
        public let codebaseId: UUID
        public let repositoryUrl: String
        public let branch: String
        public let totalFiles: Int
        public let merkleRootHash: String
        public let indexingStatus: String

        public init(
            codebaseId: UUID,
            repositoryUrl: String,
            branch: String,
            totalFiles: Int,
            merkleRootHash: String,
            indexingStatus: String
        ) {
            self.codebaseId = codebaseId
            self.repositoryUrl = repositoryUrl
            self.branch = branch
            self.totalFiles = totalFiles
            self.merkleRootHash = merkleRootHash
            self.indexingStatus = indexingStatus
        }
    }
}

// MARK: - Errors

public enum IndexGitHubError: Error, CustomStringConvertible {
    case invalidRepositoryUrl(String)
    case githubApiFailed(String)
    case repositoryCreationFailed(String)

    public var description: String {
        switch self {
        case .invalidRepositoryUrl(let url):
            return "Invalid GitHub repository URL: \(url). Must be in format: https://github.com/owner/repo"
        case .githubApiFailed(let message):
            return "GitHub API error: \(message)"
        case .repositoryCreationFailed(let message):
            return "Failed to create codebase: \(message)"
        }
    }
}
