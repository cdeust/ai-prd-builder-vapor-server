import Foundation
import Domain

/// Optimizes PRD context using intelligent chunking and summarization
/// No arbitrary token limits - handles contexts of any size through proper chunking
struct ContextOptimizer {

    /// Build optimized context using intelligent chunking strategy
    /// - Parameters:
    ///   - title: PRD title
    ///   - description: Base PRD description
    ///   - codebaseContext: Optional codebase context from RAG
    ///   - mockupAnalyses: Optional mockup analysis results
    ///   - clarifications: Optional user clarification Q&A pairs
    /// - Returns: Optimized context string (single-pass or multi-turn)
    static func buildOptimizedContext(
        title: String,
        description: String,
        codebaseContext: CodebaseContext?,
        mockupAnalyses: [MockupAnalysisResult]?,
        clarifications: [Clarification]?
    ) -> String {

        // Use intelligent chunking
        let chunkingResult = ContextChunker.chunkContext(
            title: title,
            description: description,
            codebaseContext: codebaseContext,
            mockupAnalyses: mockupAnalyses,
            clarifications: clarifications
        )

        print("📦 Context chunking result:")
        print("   - Total chunks: \(chunkingResult.chunks.count)")
        print("   - Estimated tokens: \(chunkingResult.totalEstimatedTokens)")
        print("   - Strategy: \(chunkingResult.strategy.rawValue)")

        // For single-pass strategy, combine all chunks
        if chunkingResult.strategy == .singlePass {
            return chunkingResult.chunks.map { $0.content }.joined(separator: "\n\n")
        }

        // For multi-turn or summarized, apply condensation
        return condenseChunks(chunkingResult.chunks)
    }

    /// Condense chunks for large contexts by prioritizing and summarizing
    private static func condenseChunks(_ chunks: [ContextChunker.ContextChunk]) -> String {
        // Sort by priority (lower = higher priority)
        let sortedChunks = chunks.sorted { $0.metadata.priority < $1.metadata.priority }

        var result: [String] = []

        // Always include core requirements (priority 1)
        if let coreChunk = sortedChunks.first(where: { $0.type == .core }) {
            result.append(coreChunk.content)
        }

        // Include clarifications (priority 2) - never summarize user input
        let clarificationChunks = sortedChunks.filter { $0.type == .clarifications }
        for chunk in clarificationChunks {
            result.append(chunk.content)
        }

        // Condense mockup analyses (priority 3)
        let mockupChunks = sortedChunks.filter { $0.type == .mockupAnalysis }
        if !mockupChunks.isEmpty {
            let condensed = condenseMockupChunks(mockupChunks)
            result.append(condensed)
        }

        // Condense codebase context (priority 4-5)
        let codebaseOverview = sortedChunks.first(where: { $0.type == .codebaseOverview })
        let codeFileChunks = sortedChunks.filter { $0.type == .codeFiles }

        if let overview = codebaseOverview {
            result.append(overview.content)
        }

        if !codeFileChunks.isEmpty {
            let condensed = condenseCodeFileChunks(codeFileChunks)
            result.append(condensed)
        }

        return result.joined(separator: "\n\n")
    }

    /// Condense mockup chunks by keeping key elements
    private static func condenseMockupChunks(_ chunks: [ContextChunker.ContextChunk]) -> String {
        var uiElements: [String] = []
        var userFlows: [String] = []
        var businessLogic: [String] = []

        for chunk in chunks {
            let content = chunk.content

            // Extract UI components
            if content.contains("**UI Components:**") {
                let section = content.components(separatedBy: "**UI Components:**")
                if section.count > 1 {
                    let components = section[1]
                        .components(separatedBy: "\n\n")[0]
                        .components(separatedBy: "\n")
                        .filter { !$0.isEmpty && $0.hasPrefix("-") }
                    uiElements.append(contentsOf: components)
                }
            }

            // Extract user flows
            if content.contains("**User Flows:**") {
                let section = content.components(separatedBy: "**User Flows:**")
                if section.count > 1 {
                    let flows = section[1]
                        .components(separatedBy: "\n\n")[0]
                        .components(separatedBy: "\n")
                        .filter { !$0.isEmpty && $0.hasPrefix("-") }
                    userFlows.append(contentsOf: flows)
                }
            }

            // Extract business logic
            if content.contains("**Business Logic:**") {
                let section = content.components(separatedBy: "**Business Logic:**")
                if section.count > 1 {
                    let logic = section[1]
                        .components(separatedBy: "\n\n")[0]
                        .components(separatedBy: "\n")
                        .filter { !$0.isEmpty && $0.hasPrefix("-") }
                    businessLogic.append(contentsOf: logic)
                }
            }
        }

        var result = "\n## UI/UX Requirements from Mockups\n\n"

        if !uiElements.isEmpty {
            result += "**UI Components:**\n"
            result += uiElements.prefix(20).joined(separator: "\n") + "\n\n"
        }

        if !userFlows.isEmpty {
            result += "**User Flows:**\n"
            result += userFlows.prefix(10).joined(separator: "\n") + "\n\n"
        }

        if !businessLogic.isEmpty {
            result += "**Business Logic:**\n"
            result += businessLogic.prefix(15).joined(separator: "\n") + "\n"
        }

        return result
    }

    /// Condense code file chunks by listing files with purposes (skip code excerpts)
    private static func condenseCodeFileChunks(_ chunks: [ContextChunker.ContextChunk]) -> String {
        var fileReferences: [(path: String, purpose: String)] = []

        for chunk in chunks {
            let content = chunk.content
            let lines = content.components(separatedBy: "\n")

            var currentPath: String?
            var currentPurpose: String?

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                if trimmed.hasPrefix("**") && trimmed.hasSuffix("**") && !trimmed.contains("Purpose:") {
                    // File path line
                    currentPath = trimmed.replacingOccurrences(of: "**", with: "")
                    currentPurpose = nil
                } else if trimmed.hasPrefix("Purpose:") {
                    // Purpose line
                    currentPurpose = trimmed.replacingOccurrences(of: "Purpose:", with: "").trimmingCharacters(in: .whitespaces)

                    if let path = currentPath, let purpose = currentPurpose {
                        fileReferences.append((path: path, purpose: purpose))
                    }
                }
            }
        }

        if fileReferences.isEmpty {
            return ""
        }

        var result = "\n## Codebase References (Condensed)\n\n"
        result += "The following files are relevant to this PRD:\n\n"

        for (path, purpose) in fileReferences.prefix(25) {
            result += "- **\(path)**: \(purpose)\n"
        }

        result += """

        ---

        **IMPORTANT:** Design the PRD to integrate with the existing codebase.
        Consider the current architecture, tech stack, and coding patterns.
        """

        return result
    }
}
