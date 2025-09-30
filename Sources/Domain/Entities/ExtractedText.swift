import Foundation

public struct ExtractedText: Sendable, Codable, Equatable {
    public let text: String
    public let category: TextCategory
    public let bounds: ElementBounds

    public init(text: String, category: TextCategory, bounds: ElementBounds) {
        self.text = text
        self.category = category
        self.bounds = bounds
    }
}
