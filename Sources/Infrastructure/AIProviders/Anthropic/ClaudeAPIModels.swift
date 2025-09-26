import Foundation

struct ClaudeRequest: Codable {
    let model: String
    let maxTokens: Int
    let messages: [ClaudeMessage]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
    }
}

struct ClaudeMessage: Codable {
    let role: String
    let content: String
}

struct ClaudeResponse: Codable {
    let content: String
    let usage: TokenUsage?

    enum CodingKeys: String, CodingKey {
        case content
        case usage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let contentArray = try? container.decode([ContentBlock].self, forKey: .content) {
            self.content = contentArray.compactMap { $0.text }.joined(separator: "\n")
        } else {
            self.content = try container.decode(String.self, forKey: .content)
        }

        self.usage = try? container.decode(TokenUsage.self, forKey: .usage)
    }
}

struct ContentBlock: Codable {
    let type: String
    let text: String?
}

struct TokenUsage: Codable {
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

struct RequirementsAnalysisResponse: Codable {
    let confidence: Int
    let clarificationsNeeded: [String]
    let assumptions: [String]
    let gaps: [String]
}

struct MockupAnalysisResponse: Codable {
    let extractedFeatures: [String]
    let userFlows: [String]
    let uiComponents: [String]
    let businessLogic: [String]
}