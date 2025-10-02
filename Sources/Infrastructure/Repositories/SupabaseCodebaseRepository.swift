import Foundation
import AsyncHTTPClient
import Vapor
import ImplementationAnalysis

// MARK: - Repository Errors

enum RepositoryError: Error, CustomStringConvertible {
    case saveFailed(String)
    case updateFailed(String)
    case notFound(String)
    case deleteFailed(String)
    case notImplemented(String)

    var description: String {
        switch self {
        case .saveFailed(let message): return "Save failed: \(message)"
        case .updateFailed(let message): return "Update failed: \(message)"
        case .notFound(let message): return "Not found: \(message)"
        case .deleteFailed(let message): return "Delete failed: \(message)"
        case .notImplemented(let message): return "Not implemented: \(message)"
        }
    }
}

// MARK: - Repository Implementation

/// Supabase implementation of CodebaseRepositoryProtocol
/// Uses existing SupabaseHTTPClient and SupabaseRequestBuilder patterns
public final class SupabaseCodebaseRepository: CodebaseRepositoryProtocol, @unchecked Sendable {
    private let httpClient: SupabaseHTTPClient
    private let requestBuilder: SupabaseRequestBuilder
    private let logger: Logger

    public init(
        httpClient: HTTPClient,
        supabaseURL: String,
        apiKey: String,
        schema: String = "public",
        logger: Logger = Logger(label: "supabase.codebase.repository")
    ) {
        self.httpClient = SupabaseHTTPClient(httpClient: httpClient, supabaseURL: supabaseURL, apiKey: apiKey)
        self.requestBuilder = SupabaseRequestBuilder(supabaseURL: supabaseURL, apiKey: apiKey, schema: schema)
        self.logger = logger
    }

    // MARK: - Codebase Project Operations

    public func saveProject(_ project: CodebaseProject) async throws -> CodebaseProject {
        logger.info("Saving codebase project: \(project.repositoryUrl)")

        let dto = CodebaseProjectDTO.fromDomain(project)
        let request = try requestBuilder.buildInsertRequest(tableName: "codebase_projects", model: dto)
        let results: [CodebaseProjectDTO] = try await httpClient.execute(request)

        guard let savedDTO = results.first else {
            throw RepositoryError.saveFailed("Failed to save codebase project")
        }

        logger.info("Successfully saved project: \(savedDTO.id)")
        return savedDTO.toDomain()
    }

    public func findProjectById(_ id: UUID) async throws -> CodebaseProject? {
        logger.info("Finding project by ID: \(id)")

        let request = requestBuilder.buildFindByIdRequest(tableName: "codebase_projects", id: id)
        let results: [CodebaseProjectDTO] = try await httpClient.execute(request)

        return results.first?.toDomain()
    }

    public func findProjectByRepository(url: String, branch: String) async throws -> CodebaseProject? {
        logger.info("Finding project by repository: \(url)@\(branch)")

        let filters: [(field: String, value: String, comparison: String)] = [
            ("repository_url", url, "eq"),
            ("repository_branch", branch, "eq")
        ]
        let request = requestBuilder.buildFindByMultipleFieldsRequest(
            tableName: "codebase_projects",
            filters: filters,
            limit: 1
        )
        let results: [CodebaseProjectDTO] = try await httpClient.execute(request)

        return results.first?.toDomain()
    }

    public func updateProject(_ project: CodebaseProject) async throws -> CodebaseProject {
        logger.info("Updating project: \(project.id)")

        let dto = CodebaseProjectDTO.fromDomain(project)
        let request = try requestBuilder.buildUpdateRequest(
            tableName: "codebase_projects",
            id: project.id,
            model: dto
        )
        let results: [CodebaseProjectDTO] = try await httpClient.execute(request)

        guard let updatedDTO = results.first else {
            throw RepositoryError.updateFailed("Failed to update codebase project")
        }

        logger.info("Successfully updated project: \(updatedDTO.id)")
        return updatedDTO.toDomain()
    }

    public func deleteProject(_ id: UUID) async throws {
        logger.info("Deleting project: \(id)")

        let request = requestBuilder.buildDeleteRequest(tableName: "codebase_projects", id: id)
        try await httpClient.executeDelete(request)

        logger.info("Successfully deleted project: \(id)")
    }

    public func listProjects(limit: Int, offset: Int) async throws -> [CodebaseProject] {
        logger.info("Listing projects (limit: \(limit), offset: \(offset))")

        let request = requestBuilder.buildFindByFieldRequest(
            tableName: "codebase_projects",
            field: "created_at",
            value: "2000-01-01",  // Dummy value - we use comparison "gte" to get all
            comparison: "gte",
            limit: limit,
            offset: offset,
            orderBy: "created_at"
        )
        let results: [CodebaseProjectDTO] = try await httpClient.execute(request)

        return results.map { $0.toDomain() }
    }

    // MARK: - Codebase Operations
    // NOTE: Codebase is a simplified view stored in the same codebase_projects table

    public func createCodebase(_ codebase: Codebase) async throws -> Codebase {
        logger.info("Creating codebase: \(codebase.name)")

        // Create a minimal CodebaseProject from Codebase
        let project = CodebaseProject(
            id: codebase.id,
            repositoryUrl: codebase.repositoryUrl ?? "",
            repositoryBranch: "main",
            repositoryType: .github,
            createdAt: codebase.createdAt,
            updatedAt: codebase.updatedAt
        )

        let dto = CodebaseProjectDTO.fromDomain(project)
        let request = try requestBuilder.buildInsertRequest(tableName: "codebase_projects", model: dto)
        let results: [CodebaseProjectDTO] = try await httpClient.execute(request)

        guard let savedDTO = results.first else {
            throw RepositoryError.saveFailed("Failed to create codebase")
        }

        logger.info("Successfully created codebase: \(savedDTO.id)")

        // Convert back to Codebase with the original userId
        return Codebase(
            id: savedDTO.id,
            name: codebase.name,
            repositoryUrl: savedDTO.repository_url,
            description: codebase.description,
            createdAt: savedDTO.created_at,
            updatedAt: savedDTO.updated_at,
            userId: codebase.userId
        )
    }

    public func getCodebase(by id: UUID) async throws -> Codebase? {
        logger.info("Getting codebase: \(id)")

        // TODO: Determine userId from context or use a placeholder
        // For now, using a placeholder UUID
        let placeholderUserId = UUID()

        let request = requestBuilder.buildFindByIdRequest(tableName: "codebase_projects", id: id)
        let results: [CodebaseProjectDTO] = try await httpClient.execute(request)

        guard let project = results.first else {
            return nil
        }

        // Extract name from repository URL
        let name = extractRepositoryName(from: project.repository_url)

        return Codebase(
            id: project.id,
            name: name,
            repositoryUrl: project.repository_url,
            description: nil,
            createdAt: project.created_at,
            updatedAt: project.updated_at,
            userId: placeholderUserId
        )
    }

    public func listCodebases(forUser userId: UUID) async throws -> [Codebase] {
        logger.info("Listing codebases for user: \(userId)")

        // TODO: Filter by userId when user_id field is added to schema
        // For now, return all codebases
        let request = requestBuilder.buildFindByFieldRequest(
            tableName: "codebase_projects",
            field: "created_at",
            value: "2000-01-01",
            comparison: "gte",
            limit: 100,
            orderBy: "created_at"
        )
        let results: [CodebaseProjectDTO] = try await httpClient.execute(request)

        return results.map { project in
            let name = extractRepositoryName(from: project.repository_url)
            let description = buildDescriptionFromLanguages(project.detected_languages)
            return Codebase(
                id: project.id,
                name: name,
                repositoryUrl: project.repository_url,
                description: description,
                createdAt: project.created_at,
                updatedAt: project.updated_at,
                userId: userId
            )
        }
    }

    // MARK: - Helper Methods

    private func extractRepositoryName(from url: String) -> String {
        // Extract "owner/repo" from "https://github.com/owner/repo"
        if let range = url.range(of: #"([^/]+/[^/\.]+)(?:\.git)?$"#, options: .regularExpression) {
            var name = String(url[range])
            // Remove .git suffix if present
            if name.hasSuffix(".git") {
                name = String(name.dropLast(4))
            }
            return name
        }
        return url
    }

    private func buildDescriptionFromLanguages(_ languages: [String: Int]) -> String? {
        guard !languages.isEmpty else { return nil }

        // Sort languages by bytes (descending) and take top 3
        let sortedLanguages = languages
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { $0.key }

        return sortedLanguages.joined(separator: ", ")
    }

    // MARK: - Code File Operations
    // Note: These are not implemented yet as they're not needed for basic PRD generation
    // The core functionality (project indexing and listing) works without file-level storage

    public func saveFiles(_ files: [CodeFile], projectId: UUID) async throws -> [CodeFile] {
        throw RepositoryError.notImplemented("File storage not implemented - files are fetched from GitHub on-demand")
    }

    public func addFile(_ file: CodeFile) async throws -> CodeFile {
        throw RepositoryError.notImplemented("File storage not implemented - files are fetched from GitHub on-demand")
    }

    public func findFilesByProject(_ projectId: UUID) async throws -> [CodeFile] {
        // Not stored in DB - fetch from GitHub on-demand
        return []
    }

    public func findFile(projectId: UUID, path: String) async throws -> CodeFile? {
        // Not stored in DB - fetch from GitHub on-demand
        return nil
    }

    public func updateFileParsed(fileId: UUID, isParsed: Bool, error: String?) async throws {
        throw RepositoryError.notImplemented("File parsing tracking not implemented")
    }

    // MARK: - Code Chunk Operations
    // Note: Chunking/embeddings are future features for semantic search

    public func saveChunks(_ chunks: [CodeChunk], projectId: UUID) async throws -> [CodeChunk] {
        throw RepositoryError.notImplemented("Code chunking not implemented yet")
    }

    public func findChunksByProject(_ projectId: UUID, limit: Int, offset: Int) async throws -> [CodeChunk] {
        return []
    }

    public func findChunksByFile(_ fileId: UUID) async throws -> [CodeChunk] {
        return []
    }

    public func deleteChunksByProject(_ projectId: UUID) async throws {
        // No-op - chunks not stored
    }

    // MARK: - Code Embedding Operations
    // Note: Vector search requires pgvector extension in Supabase

    public func saveEmbeddings(_ embeddings: [CodeEmbedding], projectId: UUID) async throws {
        throw RepositoryError.notImplemented("Embedding storage requires pgvector setup")
    }

    public func findSimilarChunks(
        projectId: UUID,
        queryEmbedding: [Float],
        limit: Int,
        similarityThreshold: Float
    ) async throws -> [SimilarCodeChunk] {
        return []
    }

    public func searchFiles(
        in codebaseId: UUID,
        embedding: [Float],
        limit: Int,
        similarityThreshold: Float?
    ) async throws -> [(file: CodeFile, similarity: Float)] {
        return []
    }

    // MARK: - Merkle Tree Operations
    // Note: Merkle tree is calculated but not persisted in DB

    public func saveMerkleRoot(projectId: UUID, rootHash: String) async throws {
        // Store in codebase_projects table via updateProject
        guard var project = try await findProjectById(projectId) else {
            throw RepositoryError.notFound("Project \(projectId) not found")
        }
        project = CodebaseProject(
            id: project.id,
            repositoryUrl: project.repositoryUrl,
            repositoryBranch: project.repositoryBranch,
            repositoryType: project.repositoryType,
            merkleRootHash: rootHash,
            totalFiles: project.totalFiles,
            indexedFiles: project.indexedFiles,
            totalChunks: project.totalChunks,
            indexingStatus: project.indexingStatus,
            indexingProgress: project.indexingProgress,
            lastIndexedAt: project.lastIndexedAt,
            detectedLanguages: project.detectedLanguages,
            detectedFrameworks: project.detectedFrameworks,
            architecturePatterns: project.architecturePatterns,
            createdAt: project.createdAt,
            updatedAt: Date()
        )
        _ = try await updateProject(project)
    }

    public func getMerkleRoot(projectId: UUID) async throws -> String? {
        return try await findProjectById(projectId)?.merkleRootHash
    }

    public func saveMerkleNodes(_ nodes: [MerkleNode], projectId: UUID) async throws {
        // Merkle nodes not persisted - tree rebuilt from GitHub on-demand
    }

    public func getMerkleNodes(projectId: UUID) async throws -> [MerkleNode] {
        return []
    }
}
