import Foundation
import AsyncHTTPClient
import NIOCore
import Domain

struct BusinessLogicResponse: Codable {
    let feature: String
    let description: String
    let confidence: Double?
    let requiredComponents: [String]

    // Custom decoding to provide defaults
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        feature = try container.decode(String.self, forKey: .feature)
        description = try container.decode(String.self, forKey: .description)
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence)
        requiredComponents = (try? container.decode([String].self, forKey: .requiredComponents)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case feature, description, confidence, requiredComponents
    }
}
