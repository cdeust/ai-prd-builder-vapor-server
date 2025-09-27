import Foundation

public struct RequesterInfo: Sendable, Codable {
    public let id: String
    public let name: String?
    public let email: String?

    public init(id: String, name: String? = nil, email: String? = nil) {
        self.id = id
        self.name = name
        self.email = email
    }
}

public struct GeneratePRDCommand: Sendable, Codable {
    public let requestId: UUID
    public let title: String
    public let description: String
    public let mockupSources: [MockupSource]
    public let priority: Priority
    public let requester: RequesterInfo?
    public let preferredProvider: String?
    public let options: GenerationOptions

    public init(
        requestId: UUID = UUID(),
        title: String,
        description: String,
        mockupSources: [MockupSource] = [],
        priority: Priority = .medium,
        requester: RequesterInfo? = nil,
        preferredProvider: String? = nil,
        options: GenerationOptions = GenerationOptions()
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