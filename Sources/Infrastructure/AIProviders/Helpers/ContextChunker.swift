import Foundation
import Domain

/// Intelligent context chunking strategy that splits large contexts into semantically coherent chunks
/// Each chunk maintains context integrity and can be processed independently or in sequence
struct ContextChunker {

    /// A chunk of context with metadata for processing
    struct ContextChunk: Sendable {
        let chunkId: Int
        let totalChunks: Int
        let type: ChunkType
        let content: String
        let estimatedTokens: Int
        let metadata: ChunkMetadata

        enum ChunkType: String, Sendable {
            case core = "Core Requirements"
            case clarifications = "User Clarifications"
            case mockupAnalysis = "UI/UX Analysis"
            case codebaseOverview = "Codebase Overview"
            case codeFiles = "Code References"
        }

        struct ChunkMetadata: Sendable {
            let priority: Int // Lower = higher priority
            let canBeSummarized: Bool
            let relatedChunks: [Int]
        }
    }

    /// Result of chunking operation
    struct ChunkingResult: Sendable {
        let chunks: [ContextChunk]
        let totalEstimatedTokens: Int
        let strategy: ChunkingStrategy

        enum ChunkingStrategy: String, Sendable {
            case singlePass = "Single pass (fits in context)"
            case multiTurn = "Multi-turn (requires sequential processing)"
            case summarized = "Summarized (large context condensed)"
        }
    }

    // MARK: - Configuration

    private static let targetTokensPerChunk = 2500 // Safe chunk size
    private static let contextWindowLimit = 4096
    private static let systemPromptReserve = 500 // Reserve for system prompts
    private static let maxUsableTokens = contextWindowLimit - systemPromptReserve

    // MARK: - Token Estimation

    /// Approximate token count (1 token ≈ 4 characters for English text, ≈ 3 for code)
    private static func estimateTokens(_ text: String, isCode: Bool = false) -> Int {
        return isCode ? text.count / 3 : text.count / 4
    }

    // MARK: - Main Chunking Logic

    /// Chunk context intelligently based on size and content type
    static func chunkContext(
        title: String,
        description: String,
        codebaseContext: CodebaseContext?,
        mockupAnalyses: [MockupAnalysisResult]?,
        clarifications: [Clarification]?
    ) -> ChunkingResult {

        var chunks: [ContextChunk] = []
        var totalTokens = 0

        // CHUNK 0: Core requirements (always first, highest priority)
        let coreChunk = buildCoreChunk(
            chunkId: 0,
            title: title,
            description: description
        )
        chunks.append(coreChunk)
        totalTokens += coreChunk.estimatedTokens

        // CHUNK 1: User clarifications (if available)
        if let clarifications = clarifications, !clarifications.isEmpty {
            let clarificationChunks = buildClarificationChunks(
                startingId: chunks.count,
                clarifications: clarifications
            )
            chunks.append(contentsOf: clarificationChunks)
            totalTokens += clarificationChunks.reduce(0) { $0 + $1.estimatedTokens }
        }

        // CHUNK 2+: Mockup analyses (if available)
        if let mockupAnalyses = mockupAnalyses, !mockupAnalyses.isEmpty {
            let mockupChunks = buildMockupChunks(
                startingId: chunks.count,
                analyses: mockupAnalyses
            )
            chunks.append(contentsOf: mockupChunks)
            totalTokens += mockupChunks.reduce(0) { $0 + $1.estimatedTokens }
        }

        // CHUNK N: Codebase context (if available)
        if let codebaseContext = codebaseContext {
            let codebaseChunks = buildCodebaseChunks(
                startingId: chunks.count,
                context: codebaseContext
            )
            chunks.append(contentsOf: codebaseChunks)
            totalTokens += codebaseChunks.reduce(0) { $0 + $1.estimatedTokens }
        }

        // Update totalChunks count for all chunks
        let finalChunks = chunks.map { chunk in
            ContextChunk(
                chunkId: chunk.chunkId,
                totalChunks: chunks.count,
                type: chunk.type,
                content: chunk.content,
                estimatedTokens: chunk.estimatedTokens,
                metadata: chunk.metadata
            )
        }

        // Determine strategy
        let strategy: ChunkingResult.ChunkingStrategy
        if totalTokens <= maxUsableTokens {
            strategy = .singlePass
        } else if chunks.count <= 10 {
            strategy = .multiTurn
        } else {
            strategy = .summarized
        }

        return ChunkingResult(
            chunks: finalChunks,
            totalEstimatedTokens: totalTokens,
            strategy: strategy
        )
    }

    // MARK: - Chunk Builders

    private static func buildCoreChunk(
        chunkId: Int,
        title: String,
        description: String
    ) -> ContextChunk {
        let content = """
        # \(title)

        ## Description
        \(description)

        **Note:** This is the core requirement. Additional context follows in subsequent sections.
        """

        return ContextChunk(
            chunkId: chunkId,
            totalChunks: 0, // Will be updated later
            type: .core,
            content: content,
            estimatedTokens: estimateTokens(content),
            metadata: ContextChunk.ChunkMetadata(
                priority: 1,
                canBeSummarized: false,
                relatedChunks: []
            )
        )
    }

    private static func buildClarificationChunks(
        startingId: Int,
        clarifications: [Clarification]
    ) -> [ContextChunk] {

        // If small enough, create single chunk
        let allClarificationsText = clarifications.enumerated().map { i, clarification in
            "**Q\(i + 1):** \(clarification.question)\n**A\(i + 1):** \(clarification.answer)"
        }.joined(separator: "\n\n")

        let estimatedTokens = estimateTokens(allClarificationsText)

        if estimatedTokens <= targetTokensPerChunk {
            let content = """
            ## User Clarifications

            \(allClarificationsText)
            """

            return [ContextChunk(
                chunkId: startingId,
                totalChunks: 0,
                type: .clarifications,
                content: content,
                estimatedTokens: estimateTokens(content),
                metadata: ContextChunk.ChunkMetadata(
                    priority: 2,
                    canBeSummarized: false,
                    relatedChunks: [0]
                )
            )]
        }

        // Split into multiple chunks if needed
        var chunks: [ContextChunk] = []
        var currentBatch: [String] = []
        var currentTokens = 0

        for (i, clarification) in clarifications.enumerated() {
            let entry = "**Q\(i + 1):** \(clarification.question)\n**A\(i + 1):** \(clarification.answer)"
            let tokens = estimateTokens(entry)

            if currentTokens + tokens > targetTokensPerChunk && !currentBatch.isEmpty {
                // Create chunk from current batch
                let content = """
                ## User Clarifications (Part \(chunks.count + 1))

                \(currentBatch.joined(separator: "\n\n"))
                """

                chunks.append(ContextChunk(
                    chunkId: startingId + chunks.count,
                    totalChunks: 0,
                    type: .clarifications,
                    content: content,
                    estimatedTokens: estimateTokens(content),
                    metadata: ContextChunk.ChunkMetadata(
                        priority: 2,
                        canBeSummarized: false,
                        relatedChunks: [0]
                    )
                ))

                currentBatch = []
                currentTokens = 0
            }

            currentBatch.append(entry)
            currentTokens += tokens
        }

        // Add remaining batch
        if !currentBatch.isEmpty {
            let content = """
            ## User Clarifications (Part \(chunks.count + 1))

            \(currentBatch.joined(separator: "\n\n"))
            """

            chunks.append(ContextChunk(
                chunkId: startingId + chunks.count,
                totalChunks: 0,
                type: .clarifications,
                content: content,
                estimatedTokens: estimateTokens(content),
                metadata: ContextChunk.ChunkMetadata(
                    priority: 2,
                    canBeSummarized: false,
                    relatedChunks: [0]
                )
            ))
        }

        return chunks
    }

    private static func buildMockupChunks(
        startingId: Int,
        analyses: [MockupAnalysisResult]
    ) -> [ContextChunk] {

        var chunks: [ContextChunk] = []

        // Each mockup analysis becomes its own chunk (or multiple if large)
        for (index, analysis) in analyses.enumerated() {
            let mockupContent = buildMockupAnalysisContent(analysis: analysis, index: index)
            let tokens = estimateTokens(mockupContent)

            if tokens <= targetTokensPerChunk {
                chunks.append(ContextChunk(
                    chunkId: startingId + chunks.count,
                    totalChunks: 0,
                    type: .mockupAnalysis,
                    content: mockupContent,
                    estimatedTokens: tokens,
                    metadata: ContextChunk.ChunkMetadata(
                        priority: 3,
                        canBeSummarized: true,
                        relatedChunks: [0]
                    )
                ))
            } else {
                // Split large mockup analysis
                let splitChunks = splitMockupAnalysis(
                    analysis: analysis,
                    index: index,
                    startingId: startingId + chunks.count
                )
                chunks.append(contentsOf: splitChunks)
            }
        }

        return chunks
    }

    private static func buildMockupAnalysisContent(
        analysis: MockupAnalysisResult,
        index: Int
    ) -> String {
        var parts: [String] = ["## UI/UX Requirements from Mockup \(index + 1)\n"]

        // UI Elements
        if !analysis.uiElements.isEmpty {
            let elements = analysis.uiElements.prefix(15).map { element in
                "- \(element.type): \(element.label ?? "unlabeled")"
            }.joined(separator: "\n")
            parts.append("**UI Components:**\n\(elements)\n")
        }

        // User Flows
        if !analysis.inferredUserFlows.isEmpty {
            let flows = analysis.inferredUserFlows.prefix(5).map { flow in
                "- \(flow.flowName): \(flow.steps.joined(separator: " → "))"
            }.joined(separator: "\n")
            parts.append("\n**User Flows:**\n\(flows)\n")
        }

        // Business Logic
        if !analysis.businessLogicInferences.isEmpty {
            let logic = analysis.businessLogicInferences.prefix(8).map { inference in
                "- **\(inference.feature)**: \(inference.description)"
            }.joined(separator: "\n")
            parts.append("\n**Business Logic:**\n\(logic)\n")
        }

        return parts.joined()
    }

    private static func splitMockupAnalysis(
        analysis: MockupAnalysisResult,
        index: Int,
        startingId: Int
    ) -> [ContextChunk] {

        var chunks: [ContextChunk] = []

        // Chunk 1: UI Elements
        if !analysis.uiElements.isEmpty {
            let elements = analysis.uiElements.map { element in
                "- \(element.type): \(element.label ?? "unlabeled")"
            }.joined(separator: "\n")

            let content = """
            ## Mockup \(index + 1) - UI Components

            \(elements)
            """

            chunks.append(ContextChunk(
                chunkId: startingId + chunks.count,
                totalChunks: 0,
                type: .mockupAnalysis,
                content: content,
                estimatedTokens: estimateTokens(content),
                metadata: ContextChunk.ChunkMetadata(
                    priority: 3,
                    canBeSummarized: true,
                    relatedChunks: [0]
                )
            ))
        }

        // Chunk 2: User Flows + Business Logic
        var flowsPart: [String] = []

        if !analysis.inferredUserFlows.isEmpty {
            let flows = analysis.inferredUserFlows.map { flow in
                "- \(flow.flowName): \(flow.steps.joined(separator: " → "))"
            }.joined(separator: "\n")
            flowsPart.append("**User Flows:**\n\(flows)")
        }

        if !analysis.businessLogicInferences.isEmpty {
            let logic = analysis.businessLogicInferences.map { inference in
                "- **\(inference.feature)**: \(inference.description)"
            }.joined(separator: "\n")
            flowsPart.append("\n**Business Logic:**\n\(logic)")
        }

        if !flowsPart.isEmpty {
            let content = """
            ## Mockup \(index + 1) - Flows & Logic

            \(flowsPart.joined(separator: "\n\n"))
            """

            chunks.append(ContextChunk(
                chunkId: startingId + chunks.count,
                totalChunks: 0,
                type: .mockupAnalysis,
                content: content,
                estimatedTokens: estimateTokens(content),
                metadata: ContextChunk.ChunkMetadata(
                    priority: 3,
                    canBeSummarized: true,
                    relatedChunks: [0]
                )
            ))
        }

        return chunks
    }

    private static func buildCodebaseChunks(
        startingId: Int,
        context: CodebaseContext
    ) -> [ContextChunk] {

        var chunks: [ContextChunk] = []

        // Chunk 1: Codebase Overview (always create)
        let overviewContent = buildCodebaseOverview(context: context)
        chunks.append(ContextChunk(
            chunkId: startingId,
            totalChunks: 0,
            type: .codebaseOverview,
            content: overviewContent,
            estimatedTokens: estimateTokens(overviewContent),
            metadata: ContextChunk.ChunkMetadata(
                priority: 4,
                canBeSummarized: false,
                relatedChunks: [0]
            )
        ))

        // Chunk 2+: Code file references (chunked by token limit)
        if !context.relevantFiles.isEmpty {
            let codeFileChunks = buildCodeFileChunks(
                files: context.relevantFiles,
                startingId: startingId + 1
            )
            chunks.append(contentsOf: codeFileChunks)
        }

        return chunks
    }

    private static func buildCodebaseOverview(context: CodebaseContext) -> String {
        var parts: [String] = ["## Existing Codebase Context\n"]

        parts.append("**Repository:** \(context.repositoryUrl) (branch: \(context.repositoryBranch))")
        parts.append("**Summary:** \(context.summary)\n")

        if !context.techStack.languages.isEmpty {
            let languages = context.techStack.languages
                .sorted { $0.value > $1.value }
                .prefix(10)
                .map { $0.key }
                .joined(separator: ", ")
            parts.append("**Languages:** \(languages)")
        }

        if !context.techStack.frameworks.isEmpty {
            parts.append("**Frameworks:** \(context.techStack.frameworks.prefix(10).joined(separator: ", "))")
        }

        if !context.techStack.architecturePatterns.isEmpty {
            parts.append("**Architecture:** \(context.techStack.architecturePatterns.joined(separator: ", "))")
        }

        parts.append("\n**Note:** Code references follow in subsequent sections.")

        return parts.joined(separator: "\n")
    }

    private static func buildCodeFileChunks(
        files: [CodeFileContext],
        startingId: Int
    ) -> [ContextChunk] {

        var chunks: [ContextChunk] = []
        var currentBatch: [String] = []
        var currentTokens = 0

        for file in files {
            // Build file reference with truncated excerpt
            let maxExcerptLength = 800 // ~200 tokens per file
            let truncatedExcerpt = file.excerpt.prefix(maxExcerptLength)

            let fileRef = """
            **\(file.filePath)**
            Purpose: \(file.purpose)
            ```\(file.language?.lowercased() ?? "")
            \(truncatedExcerpt)\(truncatedExcerpt.count < file.excerpt.count ? "\n... (truncated)" : "")
            ```
            """

            let tokens = estimateTokens(fileRef, isCode: true)

            if currentTokens + tokens > targetTokensPerChunk && !currentBatch.isEmpty {
                // Create chunk from current batch
                let content = """
                ## Code References (Part \(chunks.count + 1))

                \(currentBatch.joined(separator: "\n\n"))
                """

                chunks.append(ContextChunk(
                    chunkId: startingId + chunks.count,
                    totalChunks: 0,
                    type: .codeFiles,
                    content: content,
                    estimatedTokens: estimateTokens(content, isCode: true),
                    metadata: ContextChunk.ChunkMetadata(
                        priority: 5,
                        canBeSummarized: true,
                        relatedChunks: [0]
                    )
                ))

                currentBatch = []
                currentTokens = 0
            }

            currentBatch.append(fileRef)
            currentTokens += tokens
        }

        // Add remaining batch
        if !currentBatch.isEmpty {
            let content = """
            ## Code References (Part \(chunks.count + 1))

            \(currentBatch.joined(separator: "\n\n"))

            ---

            **IMPORTANT:** Design the PRD to integrate with the existing codebase above.
            Consider the current architecture, tech stack, and coding patterns.
            """

            chunks.append(ContextChunk(
                chunkId: startingId + chunks.count,
                totalChunks: 0,
                type: .codeFiles,
                content: content,
                estimatedTokens: estimateTokens(content, isCode: true),
                metadata: ContextChunk.ChunkMetadata(
                    priority: 5,
                    canBeSummarized: true,
                    relatedChunks: [0]
                )
            ))
        }

        return chunks
    }
}
