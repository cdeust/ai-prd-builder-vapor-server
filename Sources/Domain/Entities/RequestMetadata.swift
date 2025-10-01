import Foundation

public struct RequestMetadata: Sendable {
    public let tags: [String]
    public let projectId: String?
    public let version: String?
    public let preferredProvider: String?
    public let customFields: [String: String]

    public init(
        tags: [String] = [],
        projectId: String? = nil,
        version: String? = nil,
        preferredProvider: String? = nil,
        customFields: [String: String] = [:]
    ) {
        self.tags = tags
        self.projectId = projectId
        self.version = version
        self.preferredProvider = preferredProvider
        self.customFields = customFields
    }
}