import Foundation
import Domain

/// Summary model for PRD request listing
public struct PRDRequestSummary {
    public let id: UUID
    public let title: String
    public let status: RequestStatus
    public let priority: Priority
    public let createdAt: Date
    public let completedAt: Date?

    public init(
        id: UUID,
        title: String,
        status: RequestStatus,
        priority: Priority,
        createdAt: Date,
        completedAt: Date?
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.priority = priority
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}