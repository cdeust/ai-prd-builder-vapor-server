import Foundation

/// DTO for searching codebase files
public struct SearchCodebaseDTO: Codable {
    public let query: String
    public let limit: Int?
    public let similarityThreshold: Float?

    public init(
        query: String,
        limit: Int? = nil,
        similarityThreshold: Float? = nil
    ) {
        self.query = query
        self.limit = limit
        self.similarityThreshold = similarityThreshold
    }
}

/// Response DTO for search results
public struct SearchResultDTO: Codable {
    public let file: CodeFileResponseDTO
    public let similarity: Float

    public init(
        file: CodeFileResponseDTO,
        similarity: Float
    ) {
        self.file = file
        self.similarity = similarity
    }
}
