import Foundation
import AsyncHTTPClient
import Domain

/// Anthropic Claude AI provider implementation
/// Integrates with Claude API for PRD generation and analysis
public final class AnthropicProvider: AIProviderPort {
    public let name: String = "anthropic"
    public let priority: Int = 1 // High priority for quality

    private let apiKey: String
    private let httpClient: HTTPClient
    private let baseURL: String = "https://api.anthropic.com"
    private let model: String

    public init(apiKey: String, httpClient: HTTPClient, model: String = "claude-3-5-sonnet-20241022") {
        self.apiKey = apiKey
        self.httpClient = httpClient
        self.model = model
    }

    public var isAvailable: Bool {
        get async {
            // Simple health check - in production, implement proper endpoint check
            !apiKey.isEmpty
        }
    }

    public func generatePRD(from request: GeneratePRDCommand) async throws -> PRDGenerationResult {
        let startTime = Date()

        let prompt = buildPRDPrompt(request)
        let response = try await sendClaudeRequest(prompt: prompt, maxTokens: 4000)

        let processingTime = Date().timeIntervalSince(startTime)

        // Parse the response to extract sections
        let sections = extractSections(from: response.content)

        return PRDGenerationResult(
            content: response.content,
            sections: sections,
            confidence: calculateConfidence(response: response),
            metadata: GenerationMetadata(
                provider: name,
                modelVersion: model,
                processingTime: processingTime,
                tokensUsed: response.usage?.totalTokens,
                cost: calculateCost(tokensUsed: response.usage?.totalTokens)
            )
        )
    }

    public func analyzeRequirements(_ text: String) async throws -> RequirementsAnalysis {
        let prompt = buildAnalysisPrompt(text)
        let response = try await sendClaudeRequest(prompt: prompt, maxTokens: 1000)

        return parseRequirementsAnalysis(response.content)
    }

    public func extractFromMockups(_ sources: [MockupSource]) async throws -> MockupAnalysis {
        let prompt = buildMockupAnalysisPrompt(sources)
        let response = try await sendClaudeRequest(prompt: prompt, maxTokens: 1000)

        return parseMockupAnalysis(response.content)
    }

    // MARK: - Private Methods

    /// Send request to Claude API
    private func sendClaudeRequest(prompt: String, maxTokens: Int) async throws -> ClaudeResponse {
        let requestBody = ClaudeRequest(
            model: model,
            maxTokens: maxTokens,
            messages: [
                ClaudeMessage(role: "user", content: prompt)
            ]
        )

        let requestData = try JSONEncoder().encode(requestBody)

        var request = HTTPClientRequest(url: "\(baseURL)/v1/messages")
        request.method = .POST
        request.headers.add(name: "Content-Type", value: "application/json")
        request.headers.add(name: "x-api-key", value: apiKey)
        request.headers.add(name: "anthropic-version", value: "2023-06-01")
        request.body = .bytes(requestData)

        let response = try await httpClient.execute(request, timeout: .seconds(60))

        guard response.status == .ok else {
            let errorBody = try await response.body.collect(upTo: 1024 * 1024) // 1MB max
            let errorMessage = String(buffer: errorBody)
            throw DomainError.processingFailed("Anthropic API error: \(response.status) - \(errorMessage)")
        }

        let responseBody = try await response.body.collect(upTo: 10 * 1024 * 1024) // 10MB max
        let claudeResponse = try JSONDecoder().decode(ClaudeResponse.self, from: responseBody)

        return claudeResponse
    }

    /// Build PRD generation prompt
    private func buildPRDPrompt(_ request: GeneratePRDCommand) -> String {
        var prompt = """
        <task>Generate Product Requirements Document</task>

        <input>
        Title: \(request.title)
        Description: \(request.description)
        Priority: \(request.priority.rawValue)
        """

        if !request.mockupSources.isEmpty {
            prompt += "\nMockups: \(request.mockupSources.count) sources provided"
        }

        prompt += """

        Options:
        - Include Test Cases: \(request.options.includeTestCases)
        - Include API Spec: \(request.options.includeApiSpec)
        - Include Technical Details: \(request.options.includeTechnicalDetails)
        - Target Audience: \(request.options.targetAudience)
        </input>

        <instruction>
        Think carefully about this product requirement. Plan systematically and create a comprehensive PRD that includes:

        TODO: Executive Summary - Brief overview of the feature
        TODO: Problem Statement - Clear definition of what we're solving
        TODO: User Stories - Who will use this and how
        TODO: Functional Requirements - What the system must do
        TODO: Non-Functional Requirements - Performance, scalability, etc.
        TODO: Technical Requirements - Implementation considerations
        TODO: Acceptance Criteria - Definition of done
        TODO: Timeline - Development phases and milestones
        TODO: Risks - Potential challenges and mitigation strategies

        Use clear markdown formatting with proper headers. Each section should be detailed and actionable.
        """

        if let customPrompt = request.options.customPrompt {
            prompt += "\n\nAdditional Requirements:\n\(customPrompt)"
        }

        prompt += "\n</instruction>"

        return prompt
    }

    /// Build requirements analysis prompt
    private func buildAnalysisPrompt(_ text: String) -> String {
        return """
        <task>Analyze Requirements Completeness</task>

        <input>\(text)</input>

        <instruction>
        Think critically about these requirements. Analyze the completeness and clarity of the provided requirements.

        Provide your analysis in this JSON format:
        {
            "confidence": <0-100>,
            "clarificationsNeeded": [<array of specific questions>],
            "assumptions": [<array of assumptions being made>],
            "gaps": [<array of identified gaps>]
        }

        Be thorough in identifying what's missing or unclear.
        </instruction>
        """
    }

    /// Build mockup analysis prompt
    private func buildMockupAnalysisPrompt(_ sources: [MockupSource]) -> String {
        let mockupDescriptions = sources.enumerated().map { index, source in
            "Mockup \(index + 1): \(source.type.rawValue) - \(source.location)"
        }.joined(separator: "\n")

        return """
        <task>Extract Features from Mockups</task>

        <input>
        \(mockupDescriptions)
        </input>

        <instruction>
        Research and explore these mockups to extract:

        Provide your analysis in this JSON format:
        {
            "extractedFeatures": [<array of features visible in mockups>],
            "userFlows": [<array of user interaction flows>],
            "uiComponents": [<array of UI components identified>],
            "businessLogic": [<array of business rules inferred>]
        }

        Be specific about what you can see and infer from the mockups.
        </instruction>
        """
    }

    /// Extract sections from Claude response
    private func extractSections(from content: String) -> [GeneratedSection] {
        let lines = content.components(separatedBy: .newlines)
        var sections: [GeneratedSection] = []
        var currentTitle = ""
        var currentContent = ""
        var currentType = "general"

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Check for markdown headers
            if trimmedLine.hasPrefix("# ") || trimmedLine.hasPrefix("## ") || trimmedLine.hasPrefix("### ") {
                // Save previous section if exists
                if !currentTitle.isEmpty {
                    sections.append(GeneratedSection(
                        title: currentTitle,
                        content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines),
                        type: currentType
                    ))
                }

                // Start new section
                currentTitle = trimmedLine.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
                currentContent = ""
                currentType = inferSectionType(from: currentTitle)
            } else {
                currentContent += line + "\n"
            }
        }

        // Add final section
        if !currentTitle.isEmpty {
            sections.append(GeneratedSection(
                title: currentTitle,
                content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines),
                type: currentType
            ))
        }

        return sections
    }

    /// Infer section type from title
    private func inferSectionType(from title: String) -> String {
        let lowercased = title.lowercased()

        if lowercased.contains("executive") || lowercased.contains("summary") {
            return "executive_summary"
        } else if lowercased.contains("problem") {
            return "problem_statement"
        } else if lowercased.contains("user stories") || lowercased.contains("stories") {
            return "user_stories"
        } else if lowercased.contains("functional requirements") || lowercased.contains("functional") {
            return "functional_requirements"
        } else if lowercased.contains("non-functional") || lowercased.contains("performance") {
            return "non_functional_requirements"
        } else if lowercased.contains("technical") {
            return "technical_requirements"
        } else if lowercased.contains("acceptance") {
            return "acceptance_criteria"
        } else if lowercased.contains("timeline") {
            return "timeline"
        } else if lowercased.contains("risks") {
            return "risks"
        } else {
            return "general"
        }
    }

    /// Calculate confidence based on response quality
    private func calculateConfidence(response: ClaudeResponse) -> Double {
        let contentLength = response.content.count

        // Basic confidence calculation based on content length and structure
        var confidence = 0.7 // Base confidence

        if contentLength > 1000 {
            confidence += 0.1
        }
        if contentLength > 2000 {
            confidence += 0.1
        }

        // Check for structured sections
        let headerCount = response.content.components(separatedBy: "# ").count - 1
        confidence += min(0.1, Double(headerCount) * 0.02)

        return min(1.0, confidence)
    }

    /// Calculate cost based on token usage
    private func calculateCost(tokensUsed: Int?) -> Double? {
        guard let tokens = tokensUsed else { return nil }

        // Anthropic pricing (approximate)
        let inputCostPer1K = 0.003 // $0.003 per 1K input tokens
        let outputCostPer1K = 0.015 // $0.015 per 1K output tokens

        // Simple approximation: assume 70% input, 30% output
        let inputTokens = Double(tokens) * 0.7
        let outputTokens = Double(tokens) * 0.3

        let inputCost = (inputTokens / 1000.0) * inputCostPer1K
        let outputCost = (outputTokens / 1000.0) * outputCostPer1K

        return inputCost + outputCost
    }

    /// Parse requirements analysis from Claude response
    private func parseRequirementsAnalysis(_ content: String) -> RequirementsAnalysis {
        // Try to extract JSON from the response
        if let jsonData = extractJSON(from: content),
           let data = jsonData.data(using: .utf8),
           let analysisResponse = try? JSONDecoder().decode(RequirementsAnalysisResponse.self, from: data) {
            return RequirementsAnalysis(
                confidence: Double(analysisResponse.confidence),
                clarificationsNeeded: analysisResponse.clarificationsNeeded,
                assumptions: analysisResponse.assumptions,
                gaps: analysisResponse.gaps
            )
        }

        // Fallback to default analysis if JSON parsing fails
        return RequirementsAnalysis(
            confidence: 50.0,
            clarificationsNeeded: ["Unable to parse analysis - please provide more details"],
            assumptions: [],
            gaps: ["Analysis parsing failed"]
        )
    }

    /// Parse mockup analysis from Claude response
    private func parseMockupAnalysis(_ content: String) -> MockupAnalysis {
        // Try to extract JSON from the response
        if let jsonData = extractJSON(from: content),
           let data = jsonData.data(using: .utf8),
           let analysisResponse = try? JSONDecoder().decode(MockupAnalysisResponse.self, from: data) {
            return MockupAnalysis(
                extractedFeatures: analysisResponse.extractedFeatures,
                userFlows: analysisResponse.userFlows,
                uiComponents: analysisResponse.uiComponents,
                businessLogic: analysisResponse.businessLogic
            )
        }

        // Fallback if JSON parsing fails
        return MockupAnalysis(
            extractedFeatures: [],
            userFlows: [],
            uiComponents: [],
            businessLogic: []
        )
    }

    /// Extract JSON content from Claude response
    private func extractJSON(from content: String) -> String? {
        let pattern = #"\{(?:[^{}]|(?:\{[^{}]*\}))*\}"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let nsString = content as NSString
        let matches = regex?.matches(in: content, options: [], range: NSRange(location: 0, length: nsString.length))

        return matches?.first.map { nsString.substring(with: $0.range) }
    }
}

// MARK: - API Models

private struct ClaudeRequest: Codable {
    let model: String
    let maxTokens: Int
    let messages: [ClaudeMessage]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
    }
}

private struct ClaudeMessage: Codable {
    let role: String
    let content: String
}

private struct ClaudeResponse: Codable {
    let content: String
    let usage: TokenUsage?

    enum CodingKeys: String, CodingKey {
        case content
        case usage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Claude API returns content as array of content blocks
        if let contentArray = try? container.decode([ContentBlock].self, forKey: .content) {
            self.content = contentArray.compactMap { $0.text }.joined(separator: "\n")
        } else {
            self.content = try container.decode(String.self, forKey: .content)
        }

        self.usage = try? container.decode(TokenUsage.self, forKey: .usage)
    }
}

private struct ContentBlock: Codable {
    let type: String
    let text: String?
}

private struct TokenUsage: Codable {
    let inputTokens: Int
    let outputTokens: Int

    var totalTokens: Int {
        inputTokens + outputTokens
    }

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

private struct RequirementsAnalysisResponse: Codable {
    let confidence: Int
    let clarificationsNeeded: [String]
    let assumptions: [String]
    let gaps: [String]
}

private struct MockupAnalysisResponse: Codable {
    let extractedFeatures: [String]
    let userFlows: [String]
    let uiComponents: [String]
    let businessLogic: [String]
}