import Foundation

public struct GeneratePRDCommand: Sendable, Codable {
    public let requestId: UUID
    public let title: String
    public let description: String
    public let mockupSources: [MockupSource]
    public let priority: Priority
    public let preferredProvider: String?
    public let options: GenerationOptions

    public init(
        requestId: UUID = UUID(),
        title: String,
        description: String,
        mockupSources: [MockupSource] = [],
        priority: Priority = .medium,
        preferredProvider: String? = nil,
        options: GenerationOptions = GenerationOptions()
    ) {
        self.requestId = requestId
        self.title = title
        self.description = description
        self.mockupSources = mockupSources
        self.priority = priority
        self.preferredProvider = preferredProvider
        self.options = options
    }
}