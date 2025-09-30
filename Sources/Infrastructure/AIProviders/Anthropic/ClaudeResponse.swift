import Foundation

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
