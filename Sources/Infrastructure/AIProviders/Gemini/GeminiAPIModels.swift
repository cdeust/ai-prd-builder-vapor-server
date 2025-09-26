import Foundation

struct GeminiRequest: Codable {
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig?

    enum CodingKeys: String, CodingKey {
        case contents
        case generationConfig = "generation_config"
    }
}

struct GeminiContent: Codable {
    let parts: [GeminiPart]
}

struct GeminiPart: Codable {
    let text: String
}

struct GeminiGenerationConfig: Codable {
    let maxOutputTokens: Int?
    let temperature: Double?

    enum CodingKeys: String, CodingKey {
        case maxOutputTokens = "max_output_tokens"
        case temperature
    }
}

struct GeminiResponse: Codable {
    let candidates: [GeminiCandidate]?
    let usageMetadata: GeminiUsageMetadata?

    enum CodingKeys: String, CodingKey {
        case candidates
        case usageMetadata = "usage_metadata"
    }
}

struct GeminiCandidate: Codable {
    let content: GeminiContent
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case content
        case finishReason = "finish_reason"
    }
}

struct GeminiUsageMetadata: Codable {
    let promptTokenCount: Int?
    let candidatesTokenCount: Int?
    let totalTokenCount: Int?

    enum CodingKeys: String, CodingKey {
        case promptTokenCount = "prompt_token_count"
        case candidatesTokenCount = "candidates_token_count"
        case totalTokenCount = "total_token_count"
    }
}

struct GeminiRequirementsAnalysisResponse: Codable {
    let confidence: Int
    let clarificationsNeeded: [String]
    let assumptions: [String]
    let gaps: [String]
}

struct GeminiMockupAnalysisResponse: Codable {
    let extractedFeatures: [String]
    let userFlows: [String]
    let uiComponents: [String]
    let businessLogic: [String]
}