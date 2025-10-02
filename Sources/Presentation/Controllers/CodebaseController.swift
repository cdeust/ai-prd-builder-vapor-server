import Vapor
import Foundation
import Application
import Infrastructure
import ImplementationAnalysis

/// REST API controller for codebase management
/// Handles CRUD operations, GitHub indexing, and semantic search
public final class CodebaseController: RouteCollection, @unchecked Sendable {
    private let createCodebaseUseCase: CreateCodebaseUseCase
    private let getCodebaseUseCase: GetCodebaseUseCase
    private let listCodebasesUseCase: ListCodebasesUseCase
    private let indexGitHubUseCase: IndexGitHubUseCase
    private let addFileUseCase: AddFileToCodebaseUseCase
    private let searchCodebaseUseCase: SearchCodebaseUseCase
    private let linkCodebaseUseCase: LinkCodebaseToPRDUseCase
    private let githubParser: GitHubTreeParser

    public init(
        createCodebaseUseCase: CreateCodebaseUseCase,
        getCodebaseUseCase: GetCodebaseUseCase,
        listCodebasesUseCase: ListCodebasesUseCase,
        indexGitHubUseCase: IndexGitHubUseCase,
        addFileUseCase: AddFileToCodebaseUseCase,
        searchCodebaseUseCase: SearchCodebaseUseCase,
        linkCodebaseUseCase: LinkCodebaseToPRDUseCase,
        githubParser: GitHubTreeParser
    ) {
        self.createCodebaseUseCase = createCodebaseUseCase
        self.getCodebaseUseCase = getCodebaseUseCase
        self.listCodebasesUseCase = listCodebasesUseCase
        self.indexGitHubUseCase = indexGitHubUseCase
        self.addFileUseCase = addFileUseCase
        self.searchCodebaseUseCase = searchCodebaseUseCase
        self.linkCodebaseUseCase = linkCodebaseUseCase
        self.githubParser = githubParser
    }

    public func boot(routes: RoutesBuilder) throws {
        let codebases = routes.grouped("api", "v1", "codebases")

        // CRUD Operations
        codebases.post(use: createCodebase)
        codebases.get(use: listCodebases)
        codebases.get(":id", use: getCodebase)
        codebases.delete(":id", use: deleteCodebase)

        // File Operations
        codebases.post(":id", "files", use: addFile)
        codebases.get(":id", "files", use: listFiles)

        // Search
        codebases.post(":id", "search", use: searchCodebase)

        // PRD Linking
        codebases.post(":id", "link-prd", use: linkCodebaseToPRD)
        codebases.post("link-multiple", use: linkMultipleCodebasesToPRD)
        codebases.delete(":id", "link-prd", ":prdId", use: unlinkCodebase)

        // GitHub Indexing
        codebases.post("index-github", use: indexGitHubRepository)
        codebases.get(":id", "indexing-status", use: getIndexingStatus)
    }

    // MARK: - CRUD Operations

    /// POST /api/v1/codebases
    /// Create a new codebase
    @Sendable
    private func createCodebase(req: Request) async throws -> CodebaseResponseDTO {
        let dto = try req.content.decode(CreateCodebaseDTO.self)

        let input = CreateCodebaseUseCase.Input(
            name: dto.name,
            repositoryUrl: dto.repositoryUrl,
            description: dto.description,
            userId: UUID() // TODO: Extract from authenticated user
        )

        let codebase = try await createCodebaseUseCase.execute(input)
        return CodebaseMapper.toDTO(codebase)
    }

    /// GET /api/v1/codebases
    /// List all codebases for the authenticated user
    @Sendable
    private func listCodebases(req: Request) async throws -> [CodebaseResponseDTO] {
        let userId = UUID() // TODO: Extract from authenticated user

        let codebases = try await listCodebasesUseCase.execute(userId: userId)

        return CodebaseMapper.toDTOs(codebases)
    }

    /// GET /api/v1/codebases/:id
    /// Get a specific codebase by ID
    @Sendable
    private func getCodebase(req: Request) async throws -> CodebaseResponseDTO {
        guard let idString = req.parameters.get("id"),
              let id = UUID(uuidString: idString) else {
            throw Abort(.badRequest, reason: "Invalid codebase ID")
        }

        guard let codebase = try await getCodebaseUseCase.execute(codebaseId: id) else {
            throw Abort(.notFound, reason: "Codebase not found")
        }

        return CodebaseMapper.toDTO(codebase)
    }

    /// DELETE /api/v1/codebases/:id
    /// Delete a codebase and all associated data
    @Sendable
    private func deleteCodebase(req: Request) async throws -> HTTPStatus {
        guard let idString = req.parameters.get("id"),
              let id = UUID(uuidString: idString) else {
            throw Abort(.badRequest, reason: "Invalid codebase ID")
        }

        // TODO: Implement DeleteCodebaseUseCase
        req.logger.info("Deleting codebase: \(id)")

        return .noContent
    }

    // MARK: - File Operations

    /// POST /api/v1/codebases/:id/files
    /// Add a file to a codebase with automatic embedding generation
    @Sendable
    private func addFile(req: Request) async throws -> CodeFileResponseDTO {
        guard let idString = req.parameters.get("id"),
              let codebaseId = UUID(uuidString: idString) else {
            throw Abort(.badRequest, reason: "Invalid codebase ID")
        }

        let dto = try req.content.decode(AddFileDTO.self)

        let input = AddFileToCodebaseUseCase.Input(
            codebaseId: codebaseId,
            filePath: dto.filePath,
            content: dto.content,
            language: dto.language
        )

        let file = try await addFileUseCase.execute(input)
        return CodeFileMapper.toDTO(file)
    }

    /// GET /api/v1/codebases/:id/files
    /// List all files in a codebase
    @Sendable
    private func listFiles(req: Request) async throws -> [CodeFileResponseDTO] {
        guard let idString = req.parameters.get("id"),
              let codebaseId = UUID(uuidString: idString) else {
            throw Abort(.badRequest, reason: "Invalid codebase ID")
        }

        // TODO: Implement ListFilesUseCase
        req.logger.info("Listing files for codebase: \(codebaseId)")

        return []
    }

    // MARK: - Search

    /// POST /api/v1/codebases/:id/search
    /// Semantic search within a codebase
    @Sendable
    private func searchCodebase(req: Request) async throws -> [SearchResultDTO] {
        guard let idString = req.parameters.get("id"),
              let codebaseId = UUID(uuidString: idString) else {
            throw Abort(.badRequest, reason: "Invalid codebase ID")
        }

        let dto = try req.content.decode(SearchCodebaseDTO.self)

        let input = SearchCodebaseUseCase.Input(
            codebaseId: codebaseId,
            query: dto.query,
            limit: dto.limit ?? 25,
            similarityThreshold: dto.similarityThreshold ?? 0.5
        )

        let results = try await searchCodebaseUseCase.execute(input)

        return CodeFileMapper.toSearchResultDTOs(results)
    }

    // MARK: - PRD Linking

    /// POST /api/v1/codebases/:id/link-prd
    /// Link a codebase to a PRD request
    @Sendable
    private func linkCodebaseToPRD(req: Request) async throws -> LinkCodebaseResponseDTO {
        guard let idString = req.parameters.get("id"),
              let codebaseId = UUID(uuidString: idString) else {
            throw Abort(.badRequest, reason: "Invalid codebase ID")
        }

        let dto = try req.content.decode(LinkCodebaseDTO.self)

        let input = LinkCodebaseToPRDUseCase.Input(
            prdId: dto.prdRequestId,
            codebaseId: codebaseId
        )

        try await linkCodebaseUseCase.execute(input)

        return LinkCodebaseResponseDTO(
            success: true,
            prdId: dto.prdRequestId,
            codebaseId: codebaseId
        )
    }

    /// POST /api/v1/codebases/link-multiple
    /// Link multiple codebases to a PRD request in one operation
    @Sendable
    private func linkMultipleCodebasesToPRD(req: Request) async throws -> LinkMultipleCodebasesResponseDTO {
        let dto = try req.content.decode(LinkMultipleCodebasesDTO.self)

        req.logger.info("🔗 Linking \(dto.codebaseIds.count) codebases to PRD \(dto.prdRequestId)")

        var linkedIds: [UUID] = []
        var failedIds: [UUID] = []

        for codebaseId in dto.codebaseIds {
            do {
                let input = LinkCodebaseToPRDUseCase.Input(
                    prdId: dto.prdRequestId,
                    codebaseId: codebaseId
                )
                try await linkCodebaseUseCase.execute(input)
                linkedIds.append(codebaseId)
                req.logger.info("✅ Linked codebase \(codebaseId) to PRD \(dto.prdRequestId)")
            } catch {
                failedIds.append(codebaseId)
                req.logger.error("❌ Failed to link codebase \(codebaseId): \(error)")
            }
        }

        return LinkMultipleCodebasesResponseDTO(
            success: failedIds.isEmpty,
            prdId: dto.prdRequestId,
            linkedCodebaseIds: linkedIds,
            failedCodebaseIds: failedIds,
            totalRequested: dto.codebaseIds.count,
            totalLinked: linkedIds.count
        )
    }

    /// DELETE /api/v1/codebases/:id/link-prd/:prdId
    /// Unlink a codebase from a PRD request
    @Sendable
    private func unlinkCodebase(req: Request) async throws -> HTTPStatus {
        guard let idString = req.parameters.get("id"),
              let codebaseId = UUID(uuidString: idString),
              let prdIdString = req.parameters.get("prdId"),
              let prdId = UUID(uuidString: prdIdString) else {
            throw Abort(.badRequest, reason: "Invalid codebase or PRD ID")
        }

        // TODO: Implement UnlinkCodebaseUseCase
        req.logger.info("Unlinking codebase \(codebaseId) from PRD \(prdId)")

        return .noContent
    }

    // MARK: - GitHub Indexing

    /// POST /api/v1/codebases/index-github
    /// Index a GitHub repository
    @Sendable
    private func indexGitHubRepository(req: Request) async throws -> IndexGitHubResponseDTO {
        let dto = try req.content.decode(IndexGitHubRequestDTO.self)

        req.logger.info("🔍 Starting GitHub indexing for: \(dto.repositoryUrl)")

        do {
            let input = IndexGitHubUseCase.Input(
                repositoryUrl: dto.repositoryUrl,
                branch: dto.branch ?? "main",
                accessToken: dto.accessToken,
                userId: UUID() // TODO: Extract from authenticated user
            )

            let output = try await indexGitHubUseCase.execute(input)

            req.logger.info("✅ Repository indexed successfully with ID: \(output.codebaseId)")

            return IndexGitHubResponseDTO(
                codebaseId: output.codebaseId,
                repositoryUrl: output.repositoryUrl,
                branch: output.branch,
                totalFiles: output.totalFiles,
                merkleRootHash: output.merkleRootHash,
                indexingStatus: output.indexingStatus,
                message: "Repository indexing started. Check status at /api/v1/codebases/\(output.codebaseId)/indexing-status"
            )
        } catch let error as IndexGitHubError {
            req.logger.error("❌ Indexing error: \(error.description)")
            throw Abort(.badRequest, reason: error.description)
        } catch let error as GitHubError {
            req.logger.error("❌ GitHub API error: \(error.description)")
            throw Abort(.badRequest, reason: error.description)
        } catch {
            req.logger.error("❌ Unexpected error during indexing: \(error)")
            throw Abort(.internalServerError, reason: "Failed to index repository: \(error.localizedDescription)")
        }
    }

    /// GET /api/v1/codebases/:id/indexing-status
    /// Get the indexing status of a codebase
    @Sendable
    private func getIndexingStatus(req: Request) async throws -> IndexingStatusDTO {
        guard let idString = req.parameters.get("id"),
              let codebaseId = UUID(uuidString: idString) else {
            throw Abort(.badRequest, reason: "Invalid codebase ID")
        }

        // TODO: Implement GetIndexingStatusUseCase
        req.logger.info("Getting indexing status for codebase: \(codebaseId)")

        return IndexingStatusDTO(
            codebaseId: codebaseId,
            status: "pending",
            progress: 0,
            filesProcessed: 0,
            totalFiles: 0,
            chunksCreated: 0,
            embeddingsGenerated: 0,
            lastUpdated: Date()
        )
    }
}

// MARK: - Additional DTOs

struct IndexGitHubRequestDTO: Content {
    let repositoryUrl: String
    let branch: String?
    let accessToken: String?
}

struct IndexGitHubResponseDTO: Content {
    let codebaseId: UUID
    let repositoryUrl: String
    let branch: String
    let totalFiles: Int
    let merkleRootHash: String
    let indexingStatus: String
    let message: String
}

struct IndexingStatusDTO: Content {
    let codebaseId: UUID
    let status: String
    let progress: Int
    let filesProcessed: Int
    let totalFiles: Int
    let chunksCreated: Int
    let embeddingsGenerated: Int
    let lastUpdated: Date
}
