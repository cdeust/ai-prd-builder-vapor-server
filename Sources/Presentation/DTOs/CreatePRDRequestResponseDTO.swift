import Foundation
import Vapor

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
