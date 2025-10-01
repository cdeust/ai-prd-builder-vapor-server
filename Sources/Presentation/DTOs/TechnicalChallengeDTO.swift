import Foundation
import Vapor

public struct TechnicalChallengeDTO: Content {
    public let title: String
    public let description: String
    public let priority: String
    public let category: String
    public let mitigation: String?

    public init(
        title: String,
        description: String,
        priority: String,
        category: String,
        mitigation: String? = nil
    ) {
        self.title = title
        self.description = description
        self.priority = priority
        self.category = category
        self.mitigation = mitigation
    }
}
