import Foundation
import Vapor

/// DTO for PRD request summaries
public struct PRDRequestSummaryDTO: Content {
    public let id: UUID
    public let title: String
    public let status: String
    public let priority: String
    public let createdAt: Date
    public let completedAt: Date?

    public init(
        id: UUID,
        title: String,
        status: String,
        priority: String,
        createdAt: Date,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.priority = priority
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}