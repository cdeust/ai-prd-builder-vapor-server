import Foundation
import Vapor
import Domain

/// DTO for document metadata
public struct DocumentMetadataDTO: Content {
    public let format: String
    public let language: String
    public let wordCount: Int
    public let estimatedReadTime: Int
    public let tags: [String]
    public let attachments: [String]

    public init(
        format: String,
        language: String,
        wordCount: Int,
        estimatedReadTime: Int,
        tags: [String],
        attachments: [String]
    ) {
        self.format = format
        self.language = language
        self.wordCount = wordCount
        self.estimatedReadTime = estimatedReadTime
        self.tags = tags
        self.attachments = attachments
    }

    static func from(_ metadata: DocumentMetadata) -> DocumentMetadataDTO {
        return DocumentMetadataDTO(
            format: metadata.format.rawValue,
            language: metadata.language,
            wordCount: metadata.wordCount,
            estimatedReadTime: metadata.estimatedReadTime,
            tags: metadata.tags,
            attachments: metadata.attachments
        )
    }
}