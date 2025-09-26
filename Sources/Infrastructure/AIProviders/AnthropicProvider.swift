import Foundation
import AsyncHTTPClient
import Domain

public final class AnthropicProvider: AIProviderPort {
    public let name: String = "anthropic"
    public let priority: Int = 1

    private let apiClient: ClaudeAPIClient
    private let promptBuilder = ClaudePromptBuilder()
    private let responseParser = ClaudeResponseParser()
    private let costCalculator = ClaudeCostCalculator()
    private let model: String

    public init(apiKey: String, httpClient: HTTPClient, model: String = "claude-3-5-sonnet-20241022") {
        self.apiClient = ClaudeAPIClient(apiKey: apiKey, httpClient: httpClient)
        self.model = model
    }

    public var isAvailable: Bool {
        get async {
            true
        }
    }

    public func generatePRD(from request: GeneratePRDCommand) async throws -> PRDGenerationResult {
        let startTime = Date()

        let prompt = promptBuilder.buildPRDPrompt(request)
        let response = try await apiClient.sendRequest(model: model, prompt: prompt, maxTokens: 4000)

        let processingTime = Date().timeIntervalSince(startTime)
        let sections = responseParser.extractSections(from: response.content)

        return PRDGenerationResult(
            content: response.content,
            sections: sections,
            confidence: responseParser.calculateConfidence(response: response),
            metadata: GenerationMetadata(
                provider: name,
                modelVersion: model,
                processingTime: processingTime,
                tokensUsed: response.usage?.totalTokens,
                cost: costCalculator.calculateCost(tokensUsed: response.usage?.totalTokens)
            )
        )
    }

    public func analyzeRequirements(_ text: String) async throws -> Domain.RequirementsAnalysis {
        let prompt = promptBuilder.buildAnalysisPrompt(text)
        let response = try await apiClient.sendRequest(model: model, prompt: prompt, maxTokens: 1000)

        return responseParser.parseRequirementsAnalysis(response.content)
    }

    public func extractFromMockups(_ sources: [MockupSource]) async throws -> Domain.MockupAnalysis {
        let prompt = promptBuilder.buildMockupAnalysisPrompt(sources)
        let response = try await apiClient.sendRequest(model: model, prompt: prompt, maxTokens: 1000)

        return responseParser.parseMockupAnalysis(response.content)
    }
}