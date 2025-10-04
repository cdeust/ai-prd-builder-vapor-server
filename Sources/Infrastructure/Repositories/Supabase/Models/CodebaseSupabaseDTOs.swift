import Foundation
import ImplementationAnalysis

// MARK: - Codebase Project DTO

/// Supabase DTO for codebase_projects table
struct CodebaseProjectDTO: Codable {
    let id: UUID
    let repository_url: String
    let repository_branch: String
    let repository_type: String
    let merkle_root_hash: String?
    let total_files: Int
    let indexed_files: Int
    let total_chunks: Int
    let indexing_status: String
    let indexing_progress: Int
    let last_indexed_at: Date?
    let detected_languages: [String: Int]
    let detected_frameworks: [String]
    let architecture_patterns: [ArchitecturePatternDTO]
    let created_at: Date
    let updated_at: Date

    enum CodingKeys: String, CodingKey {
        case id
        case repository_url
        case repository_branch
        case repository_type
        case merkle_root_hash
        case total_files
        case indexed_files
        case total_chunks
        case indexing_status
        case indexing_progress
        case last_indexed_at
        case detected_languages
        case detected_frameworks
        case architecture_patterns
        case created_at
        case updated_at
    }
}

/// Architecture pattern DTO for JSONB storage
struct ArchitecturePatternDTO: Codable {
    let name: String
    let confidence: Double
    let evidence: [String]
}

// MARK: - Codebase DTO

/// Supabase DTO for codebase (uses codebase_projects table)
/// NOTE: We use codebase_projects table to store both CodebaseProject and Codebase
/// The difference is that Codebase is a simplified view without indexing metadata
struct CodebaseDTO: Codable {
    let id: UUID
    let repository_url: String
    let repository_branch: String
    let repository_type: String
    let created_at: Date
    let updated_at: Date

    // Note: user_id is not in the current schema, so we'll need to add it or track it separately
    // For now, we'll use a placeholder

    enum CodingKeys: String, CodingKey {
        case id
        case repository_url
        case repository_branch
        case repository_type
        case created_at
        case updated_at
    }
}

// MARK: - Code File DTO

/// Supabase DTO for code_files table
struct CodeFileDTO: Codable {
    let id: UUID
    let codebase_project_id: UUID
    let file_path: String
    let file_hash: String
    let file_size: Int
    let language: String?
    let is_parsed: Bool
    let parse_error: String?
    let created_at: Date
    let updated_at: Date

    enum CodingKeys: String, CodingKey {
        case id
        case codebase_project_id
        case file_path
        case file_hash
        case file_size
        case language
        case is_parsed
        case parse_error
        case created_at
        case updated_at
    }
}

// MARK: - Mappers

extension CodebaseProjectDTO {
    /// Convert DTO to domain model
    func toDomain() -> CodebaseProject {
        return CodebaseProject(
            id: id,
            repositoryUrl: repository_url,
            repositoryBranch: repository_branch,
            repositoryType: RepositoryType(rawValue: repository_type) ?? .github,
            merkleRootHash: merkle_root_hash,
            totalFiles: total_files,
            indexedFiles: indexed_files,
            totalChunks: total_chunks,
            indexingStatus: IndexingStatus(rawValue: indexing_status) ?? .pending,
            indexingProgress: indexing_progress,
            lastIndexedAt: last_indexed_at,
            detectedLanguages: detected_languages,
            detectedFrameworks: detected_frameworks,
            architecturePatterns: architecture_patterns.map { $0.toDomain() },
            createdAt: created_at,
            updatedAt: updated_at
        )
    }

    /// Convert domain model to DTO
    static func fromDomain(_ project: CodebaseProject) -> CodebaseProjectDTO {
        return CodebaseProjectDTO(
            id: project.id,
            repository_url: project.repositoryUrl,
            repository_branch: project.repositoryBranch,
            repository_type: project.repositoryType.rawValue,
            merkle_root_hash: project.merkleRootHash,
            total_files: project.totalFiles,
            indexed_files: project.indexedFiles,
            total_chunks: project.totalChunks,
            indexing_status: project.indexingStatus.rawValue,
            indexing_progress: project.indexingProgress,
            last_indexed_at: project.lastIndexedAt,
            detected_languages: project.detectedLanguages,
            detected_frameworks: project.detectedFrameworks,
            architecture_patterns: project.architecturePatterns.map { ArchitecturePatternDTO.fromDomain($0) },
            created_at: project.createdAt,
            updated_at: project.updatedAt
        )
    }
}

extension ArchitecturePatternDTO {
    func toDomain() -> ArchitecturePattern {
        return ArchitecturePattern(
            name: name,
            confidence: confidence,
            evidence: evidence
        )
    }

    static func fromDomain(_ pattern: ArchitecturePattern) -> ArchitecturePatternDTO {
        return ArchitecturePatternDTO(
            name: pattern.name,
            confidence: pattern.confidence,
            evidence: pattern.evidence
        )
    }
}

extension CodebaseDTO {
    /// Convert DTO to domain model
    /// NOTE: This is a simplified view - we extract name from repository_url
    /// and use a placeholder userId since the schema doesn't have user_id yet
    func toDomain(userId: UUID) -> Codebase {
        // Extract name from repository URL (e.g., "owner/repo" from "https://github.com/owner/repo")
        let name = extractRepositoryName(from: repository_url)

        return Codebase(
            id: id,
            name: name,
            repositoryUrl: repository_url,
            description: nil, // Not in codebase_projects schema
            createdAt: created_at,
            updatedAt: updated_at,
            userId: userId
        )
    }

    /// Convert domain model to DTO
    static func fromDomain(_ codebase: Codebase) -> CodebaseDTO {
        return CodebaseDTO(
            id: codebase.id,
            repository_url: codebase.repositoryUrl ?? "",
            repository_branch: "main", // Default branch
            repository_type: "github", // Default type
            created_at: codebase.createdAt,
            updated_at: codebase.updatedAt
        )
    }

    /// Extract repository name from URL
    private func extractRepositoryName(from url: String) -> String {
        // Handle URLs like "https://github.com/owner/repo" or "git@github.com:owner/repo.git"
        if let match = url.range(of: #"([^/]+/[^/\.]+)"#, options: .regularExpression) {
            return String(url[match])
        }
        return url
    }
}

extension CodeFileDTO {
    /// Convert DTO to domain model
    func toDomain() -> CodeFile {
        return CodeFile(
            id: id,
            codebaseProjectId: codebase_project_id,
            filePath: file_path,
            fileHash: file_hash,
            fileSize: file_size,
            language: language.flatMap { ProgrammingLanguage(rawValue: $0) },
            isParsed: is_parsed,
            parseError: parse_error,
            createdAt: created_at,
            updatedAt: updated_at
        )
    }

    /// Convert domain model to DTO
    static func fromDomain(_ file: CodeFile, projectId: UUID) -> CodeFileDTO {
        return CodeFileDTO(
            id: file.id,
            codebase_project_id: projectId,
            file_path: file.filePath,
            file_hash: file.fileHash,
            file_size: file.fileSize,
            language: file.language?.rawValue,
            is_parsed: file.isParsed,
            parse_error: file.parseError,
            created_at: file.createdAt,
            updated_at: file.updatedAt
        )
    }
}

// MARK: - Code Chunk DTOs

struct CodeChunkDTO: Codable {
    let id: UUID
    let codebase_project_id: UUID
    let file_id: UUID
    let file_path: String
    let start_line: Int
    let end_line: Int
    let content: String
    let content_hash: String
    let chunk_type: String
    let language: String
    let symbols: [String]
    let imports: [String]
    let token_count: Int
    let created_at: Date

    enum CodingKeys: String, CodingKey {
        case id
        case codebase_project_id
        case file_id
        case file_path
        case start_line
        case end_line
        case content
        case content_hash
        case chunk_type
        case language
        case symbols
        case imports
        case token_count
        case created_at
    }

    func toDomain() -> CodeChunk {
        return CodeChunk(
            id: id,
            codebaseProjectId: codebase_project_id,
            fileId: file_id,
            filePath: file_path,
            startLine: start_line,
            endLine: end_line,
            content: content,
            contentHash: content_hash,
            chunkType: ChunkType(rawValue: chunk_type) ?? .other,
            language: ProgrammingLanguage(rawValue: language) ?? .swift,
            symbols: symbols,
            imports: imports,
            tokenCount: token_count,
            createdAt: created_at
        )
    }

    static func fromDomain(_ chunk: CodeChunk) -> CodeChunkDTO {
        return CodeChunkDTO(
            id: chunk.id,
            codebase_project_id: chunk.codebaseProjectId,
            file_id: chunk.fileId,
            file_path: chunk.filePath,
            start_line: chunk.startLine,
            end_line: chunk.endLine,
            content: chunk.content,
            content_hash: chunk.contentHash,
            chunk_type: chunk.chunkType.rawValue,
            language: chunk.language.rawValue,
            symbols: chunk.symbols,
            imports: chunk.imports,
            token_count: chunk.tokenCount,
            created_at: chunk.createdAt
        )
    }
}

// MARK: - Code Embedding DTOs

struct CodeEmbeddingDTO: Codable {
    let id: UUID
    let chunk_id: UUID
    let codebase_project_id: UUID
    let embedding: [Float]
    let model: String
    let embedding_version: Int
    let created_at: Date

    enum CodingKeys: String, CodingKey {
        case id
        case chunk_id
        case codebase_project_id
        case embedding
        case model
        case embedding_version
        case created_at
    }

    func toDomain() -> CodeEmbedding {
        return CodeEmbedding(
            id: id,
            chunkId: chunk_id,
            codebaseProjectId: codebase_project_id,
            embedding: embedding,
            model: model,
            embeddingVersion: embedding_version,
            createdAt: created_at
        )
    }

    static func fromDomain(_ embedding: CodeEmbedding) -> CodeEmbeddingDTO {
        return CodeEmbeddingDTO(
            id: embedding.id,
            chunk_id: embedding.chunkId,
            codebase_project_id: embedding.codebaseProjectId,
            embedding: embedding.embedding,
            model: embedding.model,
            embedding_version: embedding.embeddingVersion,
            created_at: embedding.createdAt
        )
    }
}

// MARK: - Vector Search Request/Response DTOs

struct VectorSearchRequest: Codable {
    let projectId: UUID
    let queryEmbedding: [Float]
    let limit: Int
    let similarityThreshold: Float

    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case queryEmbedding = "query_embedding"
        case limit
        case similarityThreshold = "similarity_threshold"
    }
}

struct SimilarChunkDTO: Codable {
    let chunk: CodeChunkDTO
    let similarity: Double

    func toDomain() -> SimilarCodeChunk {
        return SimilarCodeChunk(
            chunk: chunk.toDomain(),
            similarity: similarity
        )
    }
}

struct FileSearchRequest: Codable {
    let codebaseId: UUID
    let queryEmbedding: [Float]
    let limit: Int
    let similarityThreshold: Float

    enum CodingKeys: String, CodingKey {
        case codebaseId = "codebase_id"
        case queryEmbedding = "query_embedding"
        case limit
        case similarityThreshold = "similarity_threshold"
    }
}

struct FileSearchResultDTO: Codable {
    let file: CodeFileDTO
    let similarity: Float
}
