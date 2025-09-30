import Foundation

struct GeminiCandidate: Codable {
    let content: GeminiContent
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case content
        case finishReason = "finish_reason"
    }
}
