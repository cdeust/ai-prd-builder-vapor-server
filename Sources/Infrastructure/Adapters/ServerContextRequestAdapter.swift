import Foundation
import Domain
import PRDGenerator
import ImplementationAnalysis
import Vapor

/// Server-side implementation of ContextRequestPort
/// Queries Supabase database and performs RAG semantic search
public final class ServerContextRequestAdapter: ContextRequestPort {
    private let codebaseRepository: CodebaseRepositoryProtocol
    private let mockupUploadRepository: MockupUploadRepositoryProtocol
    private let prdCodebaseLink: PRDCodebaseLink
    private let embeddingGenerator: EmbeddingGeneratorPort
    private let aiProvider: AIProviderPort
    private let logger: Logger

    public init(
        codebaseRepository: CodebaseRepositoryProtocol,
        mockupUploadRepository: MockupUploadRepositoryProtocol,
        prdCodebaseLink: PRDCodebaseLink,
        embeddingGenerator: EmbeddingGeneratorPort,
        aiProvider: AIProviderPort,
        logger: Logger = Logger(label: "context.request.adapter")
    ) {
        self.codebaseRepository = codebaseRepository
        self.mockupUploadRepository = mockupUploadRepository
        self.prdCodebaseLink = prdCodebaseLink
        self.embeddingGenerator = embeddingGenerator
        self.aiProvider = aiProvider
        self.logger = logger
    }

    // MARK: - ContextRequestPort Implementation

    public func requestCodebaseContext(
        projectId: UUID,
        question: String,
        searchQuery: String
    ) async throws -> CodebaseContextResponse? {
        logger.info("📦 Searching codebase for: '\(searchQuery)'")

        // Step 1: Generate embedding for search query
        let queryEmbedding = try await embeddingGenerator.generateEmbedding(text: searchQuery)

        // Step 2: Perform RAG semantic search
        let similarChunks = try await codebaseRepository.findSimilarChunks(
            projectId: projectId,
            queryEmbedding: queryEmbedding,
            limit: 5,
            similarityThreshold: 0.65
        )

        guard !similarChunks.isEmpty else {
            logger.warning("⚠️ No relevant code chunks found")
            return nil
        }

        logger.info("✅ Found \(similarChunks.count) relevant code chunks")

        // Step 3: Build context from chunks
        let domainFiles = similarChunks.map { similar in
            Domain.CodeFileContext(
                filePath: similar.chunk.filePath,
                language: similar.chunk.language.rawValue,
                excerpt: similar.chunk.content,
                purpose: "\(similar.chunk.chunkType.rawValue)\(similar.chunk.symbols.first.map { " '\($0)'" } ?? "")"
            )
        }

        // Step 4: Generate AI summary answering the question
        let summary = try await generateCodebaseSummary(
            question: question,
            chunks: similarChunks
        )

        // Step 5: Calculate average confidence
        let avgSimilarity = similarChunks.map { $0.similarity }.reduce(0, +) / Double(similarChunks.count)

        // Convert to PRDGenerator types
        let relevantFiles = domainFiles.map { file in
            PRDGenerator.CodeFileContext(
                filePath: file.filePath,
                excerpt: file.excerpt,
                purpose: file.purpose,
                similarity: avgSimilarity
            )
        }

        return CodebaseContextResponse(
            relevantFiles: relevantFiles,
            summary: summary,
            confidence: avgSimilarity,
            chunksAnalyzed: similarChunks.count
        )
    }

    public func requestMockupContext(
        requestId: UUID,
        featureQuery: String
    ) async throws -> MockupContextResponse? {
        logger.info("🎨 Searching mockups for: '\(featureQuery)'")

        // Step 1: Fetch all mockup uploads for this request
        let mockupUploads = try await mockupUploadRepository.findByRequestId(requestId)
        let uploadsWithAnalysis = mockupUploads.filter { $0.analysisResult != nil }

        guard !uploadsWithAnalysis.isEmpty else {
            logger.warning("⚠️ No mockup analyses found")
            return nil
        }

        let analyses = uploadsWithAnalysis.compactMap { $0.analysisResult }

        // Step 2: Filter analyses relevant to the feature query
        let relevant = filterRelevantMockupAnalyses(
            analyses: analyses,
            featureQuery: featureQuery
        )

        guard !relevant.isEmpty else {
            logger.warning("⚠️ No relevant mockup analyses for query")
            return nil
        }

        logger.info("✅ Found \(relevant.count) relevant mockup analyses")

        // Step 3: Generate AI summary
        let summary = try await generateMockupSummary(
            featureQuery: featureQuery,
            analyses: relevant
        )

        // Step 4: Calculate confidence based on match quality
        let confidence = calculateMockupConfidence(
            analyses: relevant,
            featureQuery: featureQuery
        )

        // Convert to PRDGenerator types (need to pair with uploads to get fileName)
        let prdGeneratorAnalyses = uploadsWithAnalysis.compactMap { upload -> PRDGenerator.MockupAnalysisResult? in
            guard let analysis = upload.analysisResult,
                  relevant.contains(where: { compareAnalyses($0, analysis) }) else {
                return nil
            }

            // Extract features from business logic inferences
            let features = analysis.businessLogicInferences.map { $0.feature }

            // Convert UserFlow to strings
            let userFlows = analysis.inferredUserFlows.map { $0.flowName }

            // Build analysis text from various components
            let analysisText = buildAnalysisText(from: analysis)

            return PRDGenerator.MockupAnalysisResult(
                fileName: upload.fileName,
                features: features,
                uiElements: analysis.uiElements.map { $0.type.rawValue },
                userFlows: userFlows,
                analysisText: analysisText
            )
        }

        return MockupContextResponse(
            relevantAnalyses: prdGeneratorAnalyses,
            summary: summary,
            confidence: confidence
        )
    }

    public func hasAdditionalContext(requestId: UUID) async -> ContextAvailability {
        // Check codebase link
        let linkedCodebase = try? await prdCodebaseLink.getCodebaseForPRD(prdRequestId: requestId)

        // Check mockup count
        let mockupCount = (try? await mockupUploadRepository.countByRequestId(requestId)) ?? 0

        // Check if codebase is indexed
        var isIndexed = false
        if let codebase = linkedCodebase {
            isIndexed = codebase.indexingStatus == .completed && codebase.totalChunks > 0
        }

        return ContextAvailability(
            hasCodebase: linkedCodebase != nil,
            hasMockups: mockupCount > 0,
            codebaseProjectId: linkedCodebase?.id,
            mockupCount: mockupCount,
            isCodebaseIndexed: isIndexed
        )
    }

    // MARK: - Private Helper Methods

    /// Generate AI summary answering the clarification question using codebase chunks
    private func generateCodebaseSummary(
        question: String,
        chunks: [SimilarCodeChunk]
    ) async throws -> String {
        let codeContext = chunks.map { chunk in
            """
            File: \(chunk.chunk.filePath)
            Type: \(chunk.chunk.chunkType.rawValue)
            Symbols: \(chunk.chunk.symbols.joined(separator: ", "))

            ```\(chunk.chunk.language.rawValue)
            \(chunk.chunk.content)
            ```
            """
        }.joined(separator: "\n\n---\n\n")

        let prompt = """
        Based on the following code context from the existing codebase, answer this question:

        **Question**: \(question)

        **Code Context**:
        \(codeContext)

        Provide a concise, technical answer (2-3 sentences max) that directly answers the question.
        Focus on what already exists in the codebase.
        """

        // Use AI provider to generate summary
        let result = try await aiProvider.generateText(from: prompt)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Generate AI summary for mockup analysis
    private func generateMockupSummary(
        featureQuery: String,
        analyses: [Domain.MockupAnalysisResult]
    ) async throws -> String {
        let mockupContext = analyses.enumerated().map { index, analysis in
            var context = "Mockup \(index + 1):\n"

            if !analysis.uiElements.isEmpty {
                let elements = analysis.uiElements.prefix(5).map { "- \($0.type): \($0.label ?? "unlabeled")" }.joined(separator: "\n")
                context += "UI Elements:\n\(elements)\n"
            }

            if !analysis.inferredUserFlows.isEmpty {
                let flows = analysis.inferredUserFlows.prefix(3).map { "- \($0.flowName)" }.joined(separator: "\n")
                context += "User Flows:\n\(flows)\n"
            }

            if !analysis.businessLogicInferences.isEmpty {
                let logic = analysis.businessLogicInferences.prefix(3).map { "- \($0.feature): \($0.description)" }.joined(separator: "\n")
                context += "Business Logic:\n\(logic)\n"
            }

            return context
        }.joined(separator: "\n\n")

        let prompt = """
        Based on the following mockup analyses, provide insight for this feature query:

        **Feature Query**: \(featureQuery)

        **Mockup Analyses**:
        \(mockupContext)

        Provide a concise answer (2-3 sentences max) describing how the mockups address this feature.
        Focus on UI/UX patterns and user flows shown in the mockups.
        """

        let result = try await aiProvider.generateText(from: prompt)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Filter mockup analyses relevant to feature query
    private func filterRelevantMockupAnalyses(
        analyses: [Domain.MockupAnalysisResult],
        featureQuery: String
    ) -> [Domain.MockupAnalysisResult] {
        let queryKeywords = featureQuery.lowercased().components(separatedBy: .whitespaces)

        return analyses.filter { analysis in
            // Check UI elements
            let hasRelevantUI = analysis.uiElements.contains { element in
                let elementText = "\(element.type) \(element.label ?? "")".lowercased()
                return queryKeywords.contains { elementText.contains($0) }
            }

            // Check user flows
            let hasRelevantFlow = analysis.inferredUserFlows.contains { flow in
                let flowText = "\(flow.flowName) \(flow.steps.joined(separator: " "))".lowercased()
                return queryKeywords.contains { flowText.contains($0) }
            }

            // Check business logic
            let hasRelevantLogic = analysis.businessLogicInferences.contains { inference in
                let logicText = "\(inference.feature) \(inference.description)".lowercased()
                return queryKeywords.contains { logicText.contains($0) }
            }

            return hasRelevantUI || hasRelevantFlow || hasRelevantLogic
        }
    }

    /// Calculate confidence score for mockup match
    private func calculateMockupConfidence(
        analyses: [Domain.MockupAnalysisResult],
        featureQuery: String
    ) -> Double {
        guard !analyses.isEmpty else { return 0.0 }

        let queryKeywords = featureQuery.lowercased().components(separatedBy: .whitespaces)
        var totalMatches = 0
        var totalPossibleMatches = 0

        for analysis in analyses {
            let elements = analysis.uiElements.count
            let flows = analysis.inferredUserFlows.count
            let logic = analysis.businessLogicInferences.count

            totalPossibleMatches += elements + flows + logic

            // Count keyword matches
            for keyword in queryKeywords where keyword.count > 2 {
                totalMatches += analysis.uiElements.filter { element in
                    "\(element.type) \(element.label ?? "")".lowercased().contains(keyword)
                }.count

                totalMatches += analysis.inferredUserFlows.filter { flow in
                    flow.flowName.lowercased().contains(keyword)
                }.count

                totalMatches += analysis.businessLogicInferences.filter { inference in
                    inference.feature.lowercased().contains(keyword)
                }.count
            }
        }

        guard totalPossibleMatches > 0 else { return 0.5 }

        let matchRatio = Double(totalMatches) / Double(totalPossibleMatches)
        return min(0.95, max(0.6, matchRatio)) // Clamp between 0.6 and 0.95
    }

    /// Compare two MockupAnalysisResult instances for equality
    private func compareAnalyses(_ lhs: Domain.MockupAnalysisResult, _ rhs: Domain.MockupAnalysisResult) -> Bool {
        return lhs.analyzedAt == rhs.analyzedAt &&
               lhs.uiElements.count == rhs.uiElements.count &&
               lhs.inferredUserFlows.count == rhs.inferredUserFlows.count
    }

    /// Build analysis text from MockupAnalysisResult
    private func buildAnalysisText(from analysis: Domain.MockupAnalysisResult) -> String {
        var text = ""

        // UI Elements
        if !analysis.uiElements.isEmpty {
            text += "UI Elements:\n"
            for element in analysis.uiElements.prefix(10) {
                text += "- \(element.type): \(element.label ?? "unlabeled")\n"
            }
            text += "\n"
        }

        // User Flows
        if !analysis.inferredUserFlows.isEmpty {
            text += "User Flows:\n"
            for flow in analysis.inferredUserFlows {
                text += "- \(flow.flowName): \(flow.steps.joined(separator: " → "))\n"
            }
            text += "\n"
        }

        // Business Logic
        if !analysis.businessLogicInferences.isEmpty {
            text += "Business Logic:\n"
            for inference in analysis.businessLogicInferences {
                text += "- \(inference.feature): \(inference.description)\n"
            }
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - AIProviderPort Extension for Text Generation

extension AIProviderPort {
    /// Generate plain text response (helper for context summaries)
    func generateText(from prompt: String) async throws -> String {
        let command = GeneratePRDCommand(
            requestId: UUID(),
            title: "Context Summary",
            description: prompt,
            mockupSources: [],
            priority: .medium,
            requester: nil,
            preferredProvider: nil,
            options: GenerationOptions()
        )

        let result = try await generatePRD(from: command, contextRequestPort: nil)
        return result.content
    }
}
