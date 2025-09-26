import Foundation
import AsyncHTTPClient
import Domain

public final class GeminiProvider: AIProviderPort {
    public let name: String = "gemini"
    public let priority: Int = 3

    private let apiClient: GeminiAPIClient
    private let promptBuilder = GeminiPromptBuilder()
    private let responseParser = GeminiResponseParser()
    private let costCalculator = GeminiCostCalculator()
    private let model: String

    public init(apiKey: String, httpClient: HTTPClient, model: String = "gemini-2.0-flash-exp") {
        self.apiClient = GeminiAPIClient(apiKey: apiKey, httpClient: httpClient)
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
        let content = response.candidates?.first?.content.parts.first?.text ?? ""

        return PRDGenerationResult(
            content: content,
            sections: sections,
            confidence: responseParser.calculateConfidence(response: response),
            metadata: GenerationMetadata(
                provider: name,
                modelVersion: model,
                processingTime: processingTime,
                tokensUsed: response.usageMetadata?.totalTokenCount,
                cost: costCalculator.calculateCost(tokensUsed: response.usageMetadata?.totalTokenCount, model: model)
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