import Foundation
import Vapor

public struct GeneratePRDRequestDTO: Content {
    public let requestId: UUID?
    public let title: String
    public let description: String
    public let mockupSources: [MockupSourceDTO]?
    public let priority: String
    public let requester: RequesterDTO?
    public let preferredProvider: String?
    public let options: GenerationOptionsDTO?

    public init(
        requestId: UUID? = nil,
        title: String,
        description: String,
        mockupSources: [MockupSourceDTO]? = nil,
        priority: String = "medium",
        requester: RequesterDTO? = nil,
        preferredProvider: String? = nil,
        options: GenerationOptionsDTO? = nil
    ) {
        self.requestId = requestId
        self.title = title
        self.description = description
        self.mockupSources = mockupSources
        self.priority = priority
        self.requester = requester
        self.preferredProvider = preferredProvider
        self.options = options
    }
}
