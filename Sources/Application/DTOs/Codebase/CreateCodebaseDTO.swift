import Foundation

/// DTO for creating a new codebase
public struct CreateCodebaseDTO: Codable {
    public let name: String
    public let repositoryUrl: String?
    public let description: String?

    public init(
        name: String,
        repositoryUrl: String?,
        description: String?
    ) {
        self.name = name
        self.repositoryUrl = repositoryUrl
        self.description = description
    }
}

/// Response DTO for codebase operations
public struct CodebaseResponseDTO: Codable {
    public let id: UUID
    public let name: String
    public let repositoryUrl: String?
    public let description: String?
    public let createdAt: Date
    public let updatedAt: Date
    public let userId: UUID

    public init(
        id: UUID,
        name: String,
        repositoryUrl: String?,
        description: String?,
        createdAt: Date,
        updatedAt: Date,
        userId: UUID
    ) {
        self.id = id
        self.name = name
        self.repositoryUrl = repositoryUrl
        self.description = description
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.userId = userId
    }
}
