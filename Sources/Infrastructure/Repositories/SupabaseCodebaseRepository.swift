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

    public func saveFiles(_ files: [CodeFile], projectId: UUID) async throws -> [CodeFile] {
        logger.info("Saving \(files.count) files for project: \(projectId)")

        guard !files.isEmpty else { return [] }

        let dtos = files.map { CodeFileDTO.fromDomain($0, projectId: projectId) }
        let request = try requestBuilder.buildInsertRequest(tableName: "code_files", model: dtos)
        let results: [CodeFileDTO] = try await httpClient.execute(request)

        logger.info("Successfully saved \(results.count) files")
        return results.map { $0.toDomain() }
    }

    public func addFile(_ file: CodeFile) async throws -> CodeFile {
        logger.info("Adding file: \(file.filePath)")

        let dto = CodeFileDTO.fromDomain(file, projectId: file.codebaseProjectId)
        let request = try requestBuilder.buildInsertRequest(tableName: "code_files", model: dto)
        let results: [CodeFileDTO] = try await httpClient.execute(request)

        guard let savedDTO = results.first else {
            throw RepositoryError.saveFailed("Failed to add file")
        }

        logger.info("Successfully added file: \(savedDTO.id)")
        return savedDTO.toDomain()
    }

    public func findFilesByProject(_ projectId: UUID) async throws -> [CodeFile] {
        logger.info("Finding files for project: \(projectId)")

        let request = requestBuilder.buildFindByFieldRequest(
            tableName: "code_files",
            field: "project_id",
            value: projectId.uuidString,
            comparison: "eq",
            limit: 10000
        )
        let results: [CodeFileDTO] = try await httpClient.execute(request)

        return results.map { $0.toDomain() }
    }

    public func findFile(projectId: UUID, path: String) async throws -> CodeFile? {
        logger.info("Finding file at path: \(path) in project: \(projectId)")

        let filters: [(field: String, value: String, comparison: String)] = [
            ("project_id", projectId.uuidString, "eq"),
            ("path", path, "eq")
        ]
        let request = requestBuilder.buildFindByMultipleFieldsRequest(
            tableName: "code_files",
            filters: filters,
            limit: 1
        )
        let results: [CodeFileDTO] = try await httpClient.execute(request)

        return results.first?.toDomain()
    }

    public func updateFileParsed(fileId: UUID, isParsed: Bool, error: String?) async throws {
        logger.info("Updating file parsed status: \(fileId)")

        struct FileParseUpdate: Codable {
            let is_parsed: Bool
            let parse_error: String?
        }

        let updateModel = FileParseUpdate(is_parsed: isParsed, parse_error: error)
        let request = try requestBuilder.buildUpdateRequest(
            tableName: "code_files",
            id: fileId,
            model: updateModel
        )
        let _: [CodeFileDTO] = try await httpClient.execute(request)

        logger.info("Successfully updated file parsed status")
    }

    // MARK: - Code Chunk Operations

    public func saveChunks(_ chunks: [CodeChunk], projectId: UUID) async throws -> [CodeChunk] {
        logger.info("Saving \(chunks.count) chunks for project: \(projectId)")

        guard !chunks.isEmpty else { return [] }

        let dtos = chunks.map { CodeChunkDTO.fromDomain($0) }
        let request = try requestBuilder.buildInsertRequest(tableName: "code_chunks", model: dtos)
        let results: [CodeChunkDTO] = try await httpClient.execute(request)

        logger.info("Successfully saved \(results.count) chunks")
        return results.map { $0.toDomain() }
    }

    public func findChunksByProject(_ projectId: UUID, limit: Int, offset: Int) async throws -> [CodeChunk] {
        logger.info("Finding chunks for project: \(projectId) (limit: \(limit), offset: \(offset))")

        let request = requestBuilder.buildFindByFieldRequest(
            tableName: "code_chunks",
            field: "project_id",
            value: projectId.uuidString,
            comparison: "eq",
            limit: limit,
            offset: offset
        )
        let results: [CodeChunkDTO] = try await httpClient.execute(request)

        return results.map { $0.toDomain() }
    }

    public func findChunksByFile(_ fileId: UUID) async throws -> [CodeChunk] {
        logger.info("Finding chunks for file: \(fileId)")

        let request = requestBuilder.buildFindByFieldRequest(
            tableName: "code_chunks",
            field: "file_id",
            value: fileId.uuidString,
            comparison: "eq",
            limit: 1000
        )
        let results: [CodeChunkDTO] = try await httpClient.execute(request)

        return results.map { $0.toDomain() }
    }

    public func deleteChunksByProject(_ projectId: UUID) async throws {
        logger.info("Deleting chunks for project: \(projectId)")

        let request = requestBuilder.buildDeleteByFieldRequest(
            tableName: "code_chunks",
            field: "project_id",
            value: projectId.uuidString
        )
        try await httpClient.executeDelete(request)

        logger.info("Successfully deleted chunks for project")
    }

    // MARK: - Code Embedding Operations

    public func saveEmbeddings(_ embeddings: [CodeEmbedding], projectId: UUID) async throws {
        logger.info("Saving \(embeddings.count) embeddings for project: \(projectId)")

        guard !embeddings.isEmpty else { return }

        let dtos = embeddings.map { CodeEmbeddingDTO.fromDomain($0) }
        let request = try requestBuilder.buildInsertRequest(tableName: "code_embeddings", model: dtos)
        _ = try await httpClient.execute(request) as [CodeEmbeddingDTO]

        logger.info("Successfully saved \(embeddings.count) embeddings")
    }

    public func findSimilarChunks(
        projectId: UUID,
        queryEmbedding: [Float],
        limit: Int,
        similarityThreshold: Float
    ) async throws -> [SimilarCodeChunk] {
        logger.info("Finding similar chunks for project: \(projectId) (threshold: \(similarityThreshold))")

        // Use Supabase's RPC function for vector similarity search
        // This requires pgvector extension and a custom function in Supabase
        let rpcRequest = VectorSearchRequest(
            projectId: projectId,
            queryEmbedding: queryEmbedding,
            limit: limit,
            similarityThreshold: similarityThreshold
        )

        let encoder = JSONEncoder()
        let requestData = try encoder.encode(rpcRequest)

        var request = HTTPClientRequest(url: "\(requestBuilder.supabaseURL)/rest/v1/rpc/find_similar_code_chunks")
        request.method = .POST
        request.headers.add(name: "Authorization", value: "Bearer \(requestBuilder.apiKey)")
        request.headers.add(name: "apikey", value: requestBuilder.apiKey)
        request.headers.add(name: "Content-Type", value: "application/json")
        request.headers.add(name: "Content-Profile", value: requestBuilder.schema)
        request.headers.add(name: "Accept-Profile", value: requestBuilder.schema)
        request.body = .bytes(requestData)

        let results: [SimilarChunkDTO] = try await httpClient.execute(request)

        logger.info("Found \(results.count) similar chunks")
        return results.map { $0.toDomain() }
    }

    public func searchFiles(
        in codebaseId: UUID,
        embedding: [Float],
        limit: Int,
        similarityThreshold: Float?
    ) async throws -> [(file: CodeFile, similarity: Float)] {
        logger.info("Searching files in codebase: \(codebaseId)")

        // Use RPC function for file-level semantic search
        let rpcRequest = FileSearchRequest(
            codebaseId: codebaseId,
            queryEmbedding: embedding,
            limit: limit,
            similarityThreshold: similarityThreshold ?? 0.7
        )

        let encoder = JSONEncoder()
        let requestData = try encoder.encode(rpcRequest)

        var request = HTTPClientRequest(url: "\(requestBuilder.supabaseURL)/rest/v1/rpc/search_code_files")
        request.method = .POST
        request.headers.add(name: "Authorization", value: "Bearer \(requestBuilder.apiKey)")
        request.headers.add(name: "apikey", value: requestBuilder.apiKey)
        request.headers.add(name: "Content-Type", value: "application/json")
        request.headers.add(name: "Content-Profile", value: requestBuilder.schema)
        request.headers.add(name: "Accept-Profile", value: requestBuilder.schema)
        request.body = .bytes(requestData)

        let results: [FileSearchResultDTO] = try await httpClient.execute(request)

        logger.info("Found \(results.count) matching files")
        return results.map { (file: $0.file.toDomain(), similarity: $0.similarity) }
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
