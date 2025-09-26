import Foundation
import Domain

/// Response model for generation status query
public struct GenerationStatusResponse {
    public let requestId: UUID
    public let status: RequestStatus
    public let progress: Int
    public let document: PRDDocument?
    public let createdAt: Date
    public let updatedAt: Date
    public let completedAt: Date?

    public init(
        requestId: UUID,
        status: RequestStatus,
        progress: Int,
        document: PRDDocument?,
        createdAt: Date,
        updatedAt: Date,
        completedAt: Date?
    ) {
        self.requestId = requestId
        self.status = status
        self.progress = progress
        self.document = document
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }
}