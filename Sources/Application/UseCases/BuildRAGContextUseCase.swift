import Foundation
import ImplementationAnalysis
import Domain

/// Use case for building RAG (Retrieval-Augmented Generation) context for PRD generation
/// Uses semantic search to find the most relevant code chunks based on PRD requirements
public struct BuildRAGContextUseCase {
    private let codebaseRepository: CodebaseRepositoryProtocol
    private let embeddingGenerator: EmbeddingGeneratorPort

    public init(
        codebaseRepository: CodebaseRepositoryProtocol,
        embeddingGenerator: EmbeddingGeneratorPort
    ) {
        self.codebaseRepository = codebaseRepository
        self.embeddingGenerator = embeddingGenerator
    }

    public struct Input {
        public let projectId: UUID
        public let prdDescription: String
        public let prdTitle: String
        public let maxChunks: Int
        public let similarityThreshold: Float

        public init(
            projectId: UUID,
            prdDescription: String,
            prdTitle: String,
            maxChunks: Int = 10,
            similarityThreshold: Float = 0.7
        ) {
            self.projectId = projectId
            self.prdDescription = prdDescription
            self.prdTitle = prdTitle
            self.maxChunks = maxChunks
            self.similarityThreshold = similarityThreshold
        }
    }

    public struct Output {
        public let relevantChunks: [RelevantCodeChunk]
        public let totalChunksSearched: Int
        public let averageSimilarity: Double

        public init(
            relevantChunks: [RelevantCodeChunk],
            totalChunksSearched: Int,
            averageSimilarity: Double
        ) {
            self.relevantChunks = relevantChunks
            self.totalChunksSearched = totalChunksSearched
            self.averageSimilarity = averageSimilarity
        }
    }

    public struct RelevantCodeChunk {
        public let filePath: String
        public let content: String
        public let startLine: Int
        public let endLine: Int
        public let chunkType: String
        public let symbolName: String?
        public let similarity: Double
        public let language: String

        public init(
            filePath: String,
            content: String,
            startLine: Int,
            endLine: Int,
            chunkType: String,
            symbolName: String?,
            similarity: Double,
            language: String
        ) {
            self.filePath = filePath
            self.content = content
            self.startLine = startLine
            self.endLine = endLine
            self.chunkType = chunkType
            self.symbolName = symbolName
            self.similarity = similarity
            self.language = language
        }
    }

    public func execute(_ input: Input) async throws -> Output {
        // Step 1: Create search query from PRD title and description
        let searchQuery = buildSearchQuery(title: input.prdTitle, description: input.prdDescription)

        // Step 2: Generate embedding for the search query
        let queryEmbedding = try await embeddingGenerator.generateEmbedding(text: searchQuery)

        // Step 3: Perform similarity search in the codebase
        let similarChunks = try await codebaseRepository.findSimilarChunks(
            projectId: input.projectId,
            queryEmbedding: queryEmbedding,
            limit: input.maxChunks,
            similarityThreshold: input.similarityThreshold
        )

        // Step 4: Map to output format
        let relevantChunks = similarChunks.map { similarChunk in
            RelevantCodeChunk(
                filePath: similarChunk.chunk.filePath,
                content: similarChunk.chunk.content,
                startLine: similarChunk.chunk.startLine,
                endLine: similarChunk.chunk.endLine,
                chunkType: similarChunk.chunk.chunkType.rawValue,
                symbolName: similarChunk.chunk.symbols.first,
                similarity: similarChunk.similarity,
                language: similarChunk.chunk.language.rawValue
            )
        }

        // Calculate statistics
        let avgSimilarity = relevantChunks.isEmpty ? 0.0 : relevantChunks.map { $0.similarity }.reduce(0, +) / Double(relevantChunks.count)

        return Output(
            relevantChunks: relevantChunks,
            totalChunksSearched: similarChunks.count,
            averageSimilarity: avgSimilarity
        )
    }

    /// Build effective search query from PRD details
    /// Combines title and description with emphasis on technical requirements
    private func buildSearchQuery(title: String, description: String) -> String {
        // Combine title and description, prioritizing description
        var query = title

        // Extract key technical terms from description
        let technicalKeywords = extractTechnicalKeywords(from: description)
        if !technicalKeywords.isEmpty {
            query += " " + technicalKeywords.joined(separator: " ")
        }

        // Limit query length (embeddings work best with focused queries)
        let words = query.split(separator: " ")
        if words.count > 50 {
            query = words.prefix(50).joined(separator: " ")
        }

        return query
    }

    /// Extract technical keywords from description
    /// Looks for programming concepts, patterns, and technical terms
    private func extractTechnicalKeywords(from text: String) -> [String] {
        // Common technical patterns and keywords
        let patterns = [
            "api", "authentication", "database", "cache", "queue",
            "service", "repository", "controller", "model", "view",
            "async", "sync", "real-time", "webhook", "rest", "graphql",
            "storage", "persistence", "validation", "security", "encryption",
            "performance", "optimization", "scalability", "architecture"
        ]

        let lowercased = text.lowercased()
        var found: [String] = []

        for pattern in patterns {
            if lowercased.contains(pattern) {
                found.append(pattern)
            }
        }

        return found
    }

    /// Convert RAG context to CodebaseContext format for PRD generation
    public static func toCodebaseContext(
        ragOutput: Output,
        projectId: UUID,
        repositoryUrl: String,
        repositoryBranch: String,
        summary: String,
        techStack: TechStackInfo
    ) -> CodebaseContext {
        let relevantFiles = ragOutput.relevantChunks.map { chunk in
            CodeFileContext(
                filePath: chunk.filePath,
                language: chunk.language,
                excerpt: chunk.content,
                purpose: "Code reference: \(chunk.chunkType)\(chunk.symbolName.map { " '\($0)'" } ?? "") (similarity: \(String(format: "%.2f", chunk.similarity)))"
            )
        }

        return CodebaseContext(
            projectId: projectId,
            repositoryUrl: repositoryUrl,
            repositoryBranch: repositoryBranch,
            summary: summary + " (RAG-enhanced with \(ragOutput.totalChunksSearched) relevant code chunks, avg similarity: \(String(format: "%.2f", ragOutput.averageSimilarity)))",
            relevantFiles: relevantFiles,
            techStack: techStack
        )
    }
}
