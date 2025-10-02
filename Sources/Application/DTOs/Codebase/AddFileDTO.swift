import Foundation

/// DTO for adding a file to a codebase
public struct AddFileDTO: Codable {
    public let filePath: String
    public let content: String
    public let language: String?

    public init(
        filePath: String,
        content: String,
        language: String?
    ) {
        self.filePath = filePath
        self.content = content
        self.language = language
    }
}

/// Response DTO for code file operations
public struct CodeFileResponseDTO: Codable {
    public let id: UUID
    public let codebaseId: UUID
    public let filePath: String
    public let content: String
    public let language: String?
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID,
        codebaseId: UUID,
        filePath: String,
        content: String,
        language: String?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.codebaseId = codebaseId
        self.filePath = filePath
        self.content = content
        self.language = language
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
