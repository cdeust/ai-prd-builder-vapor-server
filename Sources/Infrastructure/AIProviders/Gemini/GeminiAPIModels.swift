import Foundation

struct GeminiRequest: Codable {
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig?

    enum CodingKeys: String, CodingKey {
        case contents
        case generationConfig = "generation_config"
    }
}
