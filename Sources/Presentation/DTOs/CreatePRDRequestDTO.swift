import Foundation
import Vapor

/// DTO for creating a PRD request (Request-First workflow)
public struct CreatePRDRequestDTO: Content {
    public let requestId: UUID?
    public let title: String
    public let description: String
    public let priority: String?
    public let requester: RequesterDTO?

    public init(
        requestId: UUID? = nil,
        title: String,
        description: String,
        priority: String? = "medium",
        requester: RequesterDTO? = nil
    ) {
        self.requestId = requestId
        self.title = title
        self.description = description
        self.priority = priority
        self.requester = requester
    }
}

/// Response DTO for created PRD request
public struct CreatePRDRequestResponseDTO: Content {
    public let requestId: String
    public let title: String
    public let description: String
    public let status: String
    public let createdAt: Date
    public let message: String

    public init(
        requestId: String,
        title: String,
        description: String,
        status: String,
        createdAt: Date,
        message: String
    ) {
        self.requestId = requestId
        self.title = title
        self.description = description
        self.status = status
        self.createdAt = createdAt
        self.message = message
    }
}
