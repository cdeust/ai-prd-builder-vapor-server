import Foundation

struct GeminiResponse: Codable {
    let candidates: [GeminiCandidate]?
    let usageMetadata: GeminiUsageMetadata?

    enum CodingKeys: String, CodingKey {
        case candidates
        case usageMetadata = "usage_metadata"
    }
}
