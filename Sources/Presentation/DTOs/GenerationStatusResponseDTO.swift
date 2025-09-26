import Foundation
import Vapor

/// DTO for generation status responses
public struct GenerationStatusResponseDTO: Content {
    public let requestId: UUID
    public let status: String
    public let progress: Int
    public let document: PRDDocumentDTO?
    public let createdAt: Date
    public let updatedAt: Date
    public let completedAt: Date?

    public init(
        requestId: UUID,
        status: String,
        progress: Int,
        document: PRDDocumentDTO? = nil,
        createdAt: Date,
        updatedAt: Date,
        completedAt: Date? = nil
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