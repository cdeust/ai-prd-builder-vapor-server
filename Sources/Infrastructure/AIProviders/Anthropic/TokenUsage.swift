import Foundation

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
