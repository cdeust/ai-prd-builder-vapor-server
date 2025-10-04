import Foundation
import Domain
import CommonModels

/// Message in a conversation history
struct ConversationMessage: Sendable {
    enum Role: String, Sendable {
        case user
        case assistant
    }

    let role: Role
    let content: String
}

/// Multi-turn context injection strategy for handling large contexts
/// Sends context in multiple turns, allowing the AI to process information incrementally
struct MultiTurnContextStrategy {

    /// Inject context chunks using a multi-turn conversation approach
    /// - Parameters:
    ///   - chunks: Ordered chunks from ContextChunker
    ///   - provider: AI provider to use
    ///   - initialPrompt: Initial PRD generation instruction
    /// - Returns: Accumulated context from all turns
    static func injectChunksSequentially(
        chunks: [ContextChunker.ContextChunk],
        provider: AIProvider,
        initialPrompt: String
    ) async throws -> String {

        guard !chunks.isEmpty else {
            return initialPrompt
        }

        // Strategy depends on number of chunks
        if chunks.count == 1 {
            // Single chunk - just combine
            return "\(chunks[0].content)\n\n---\n\n\(initialPrompt)"
        }

        // Multi-chunk strategy: Sequential context building with conversation history
        return try await buildContextSequentially(
            chunks: chunks,
            provider: provider,
            finalPrompt: initialPrompt
        )
    }

    /// Build context through sequential AI interactions with message history
    private static func buildContextSequentially(
        chunks: [ContextChunker.ContextChunk],
        provider: AIProvider,
        finalPrompt: String
    ) async throws -> String {

        var conversationHistory: [ConversationMessage] = []
        var contextSummary: String = ""

        // Process high-priority chunks first (core, clarifications, mockups)
        let prioritizedChunks = chunks.sorted { $0.metadata.priority < $1.metadata.priority }

        // Start with system context establishment
        let systemMessage = """
        I'm going to provide you with context for a PRD generation task in multiple parts.
        Please acknowledge each part and remember the information. I'll tell you when to generate the final PRD.
        """
        conversationHistory.append(ConversationMessage(role: .user, content: systemMessage))

        // Process each chunk through the AI
        for (index, chunk) in prioritizedChunks.enumerated() {
            let isLast = (index == prioritizedChunks.count - 1)

            if isLast {
                // Last chunk: Include final PRD generation instruction
                let finalMessage = """
                Here is the final piece of context:

                \(chunk.content)

                ---

                Now that you have all the context, please:
                \(finalPrompt)
                """

                conversationHistory.append(ConversationMessage(role: .user, content: finalMessage))

                // Build the final context with full history
                return buildContextFromHistory(conversationHistory: conversationHistory)

            } else {
                // Send chunk to AI for acknowledgment and summarization
                let chunkMessage = """
                Part \(index + 1) of \(prioritizedChunks.count):

                ## \(chunk.type.rawValue)

                \(chunk.content)

                Please acknowledge this information and provide a brief summary of the key points.
                """

                conversationHistory.append(ConversationMessage(role: .user, content: chunkMessage))

                // For now, simulate AI acknowledgment (in production, would actually call provider)
                // This would be: let response = try await provider.chat(messages: conversationHistory)
                let acknowledgment = generateAcknowledgment(for: chunk)
                conversationHistory.append(ConversationMessage(role: .assistant, content: acknowledgment))

                // Build running summary
                if chunk.metadata.canBeSummarized {
                    contextSummary += summarizeChunk(chunk)
                } else {
                    contextSummary += "\n\n## \(chunk.type.rawValue)\n\(chunk.content)\n"
                }
            }
        }

        return contextSummary + "\n\n---\n\n" + finalPrompt
    }

    /// Generate acknowledgment for a chunk (simulates AI understanding)
    private static func generateAcknowledgment(for chunk: ContextChunker.ContextChunk) -> String {
        switch chunk.type {
        case .core:
            return "Understood. I've noted the core requirements and objectives."
        case .clarifications:
            return "Acknowledged. I've recorded the user clarifications and will incorporate them."
        case .mockupAnalysis:
            return "Got it. I've captured the UI/UX requirements and user flows from the mockup analysis."
        case .codebaseOverview:
            return "Understood. I've noted the existing codebase tech stack and architecture."
        case .codeFiles:
            return "Acknowledged. I've recorded the relevant code file references for integration context."
        }
    }

    /// Build context from conversation history
    private static func buildContextFromHistory(conversationHistory: [ConversationMessage]) -> String {
        // Combine all messages into a coherent context
        var context = ""

        for message in conversationHistory {
            let prefix = message.role == .user ? "📝 Context:" : "✓ Acknowledged:"
            context += "\(prefix)\n\(message.content)\n\n---\n\n"
        }

        return context
    }

    /// Summarize a chunk to reduce token usage
    private static func summarizeChunk(_ chunk: ContextChunker.ContextChunk) -> String {
        switch chunk.type {
        case .core:
            return chunk.content // Never summarize core requirements

        case .clarifications:
            // Keep clarifications as-is (user's direct input)
            return "\n\n## User Clarifications\n\(chunk.content)\n"

        case .mockupAnalysis:
            // Extract key points from mockup analysis
            return extractMockupKeyPoints(from: chunk.content)

        case .codebaseOverview:
            return chunk.content // Keep overview full

        case .codeFiles:
            // Condense code references to file paths and purposes
            return condensedCodeReferences(from: chunk.content)
        }
    }

    private static func extractMockupKeyPoints(from content: String) -> String {
        // Extract UI components, flows, and logic without full details
        var keyPoints: [String] = []

        // Look for UI Components
        if content.contains("**UI Components:**") {
            let uiSection = content.components(separatedBy: "**UI Components:**")
            if uiSection.count > 1 {
                let components = uiSection[1]
                    .components(separatedBy: "\n\n")[0]
                    .components(separatedBy: "\n")
                    .filter { !$0.isEmpty }
                    .prefix(8)
                    .joined(separator: "\n")
                keyPoints.append("**UI Components:**\n\(components)")
            }
        }

        // Look for User Flows
        if content.contains("**User Flows:**") {
            let flowSection = content.components(separatedBy: "**User Flows:**")
            if flowSection.count > 1 {
                let flows = flowSection[1]
                    .components(separatedBy: "\n\n")[0]
                    .components(separatedBy: "\n")
                    .filter { !$0.isEmpty }
                    .prefix(5)
                    .joined(separator: "\n")
                keyPoints.append("**User Flows:**\n\(flows)")
            }
        }

        // Look for Business Logic
        if content.contains("**Business Logic:**") {
            let logicSection = content.components(separatedBy: "**Business Logic:**")
            if logicSection.count > 1 {
                let logic = logicSection[1]
                    .components(separatedBy: "\n\n")[0]
                    .components(separatedBy: "\n")
                    .filter { !$0.isEmpty }
                    .prefix(5)
                    .joined(separator: "\n")
                keyPoints.append("**Business Logic:**\n\(logic)")
            }
        }

        return keyPoints.isEmpty ? "" : "\n\n## UI/UX Analysis Summary\n\(keyPoints.joined(separator: "\n\n"))\n"
    }

    private static func condensedCodeReferences(from content: String) -> String {
        // Extract file paths and purposes, skip code excerpts
        let lines = content.components(separatedBy: "\n")
        var references: [String] = []

        for line in lines {
            if line.hasPrefix("**") && line.contains("**") && !line.contains("Purpose:") {
                // File path line
                let filePath = line.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespaces)
                references.append("- \(filePath)")
            } else if line.hasPrefix("Purpose:") {
                // Purpose line
                if let last = references.last {
                    references[references.count - 1] = last + " - \(line)"
                }
            }
        }

        if references.isEmpty {
            return ""
        }

        return """

        ## Codebase References (Condensed)

        \(references.prefix(20).joined(separator: "\n"))

        """
    }

    /// Build final context by combining summary with critical chunks
    private static func buildFinalContext(
        contextSummary: String,
        finalChunk: String,
        allChunks: [ContextChunker.ContextChunk]
    ) -> String {

        // Always include core chunk
        let coreChunk = allChunks.first { $0.type == .core }

        var finalContext = coreChunk?.content ?? ""

        // Add condensed summary of other contexts
        if !contextSummary.isEmpty {
            finalContext += "\n\n" + contextSummary
        }

        // Add final instruction
        finalContext += "\n\n---\n\n" + finalChunk

        return finalContext
    }
}

// MARK: - Helper Extensions

extension ContextChunker.ContextChunk.ChunkType {
    var displayName: String {
        return self.rawValue
    }
}
