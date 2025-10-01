import Foundation
import AsyncHTTPClient
import Domain

public final class OpenAIProvider: AIProviderPort {
    public let name: String = "openai"
    public let priority: Int = 2

    private let apiClient: OpenAIAPIClient
    private let promptBuilder = OpenAIPromptBuilder()
    private let responseParser = OpenAIResponseParser()
    private let costCalculator = OpenAICostCalculator()
    private let model: String

    public init(apiKey: String, httpClient: HTTPClient, model: String = "gpt-5-turbo-2025-01-01") {
        self.apiClient = OpenAIAPIClient(apiKey: apiKey, httpClient: httpClient)
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
        let sections = responseParser.extractSections(from: response)

        return PRDGenerationResult(
            content: response.choices.first?.message.content ?? "",
            sections: sections,
            confidence: responseParser.calculateConfidence(response: response),
            metadata: GenerationMetadata(
                provider: name,
                modelVersion: model,
                processingTime: processingTime,
                tokensUsed: response.usage?.totalTokens,
                cost: costCalculator.calculateCost(tokensUsed: response.usage?.totalTokens, model: model)
            )
        )
    }

    public func analyzeRequirements(_ text: String) async throws -> Domain.RequirementsAnalysis {
        let prompt = promptBuilder.buildAnalysisPrompt(text)
        let response = try await apiClient.sendRequest(model: model, prompt: prompt, maxTokens: 1000)

        return responseParser.parseRequirementsAnalysis(from: response)
    }

    public func extractFromMockups(_ sources: [MockupSource]) async throws -> Domain.MockupAnalysis {
        let prompt = promptBuilder.buildMockupAnalysisPrompt(sources)
        let response = try await apiClient.sendRequest(model: model, prompt: prompt, maxTokens: 1000)

        return responseParser.parseMockupAnalysis(from: response)
    }
}