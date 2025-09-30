import Foundation

struct GeminiGenerationConfig: Codable {
    let maxOutputTokens: Int?
    let temperature: Double?

    enum CodingKeys: String, CodingKey {
        case maxOutputTokens = "max_output_tokens"
        case temperature
    }
}
