import Foundation

/// Domain entity representing a technical challenge that could impact the project
public struct DomainTechnicalChallenge: Sendable {
    public let title: String
    public let description: String
    public let priority: Priority
    public let category: String
    public let mitigation: String?

    public enum Priority: String, Sendable {
        case critical = "critical"
        case high = "high"
        case medium = "medium"
        case low = "low"
    }

    public init(
        title: String,
        description: String,
        priority: Priority,
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
