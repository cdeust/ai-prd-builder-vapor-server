import Foundation
import Vapor
import Domain

/// DTO for PRD documents
public struct PRDDocumentDTO: Content {
    public let id: UUID
    public let requestId: UUID
    public let title: String
    public let content: String
    public let sections: [PRDSectionDTO]
    public let metadata: DocumentMetadataDTO
    public let generatedAt: Date
    public let generatedBy: String
    public let confidence: Double
    public let version: Int

    public init(
        id: UUID,
        requestId: UUID,
        title: String,
        content: String,
        sections: [PRDSectionDTO],
        metadata: DocumentMetadataDTO,
        generatedAt: Date,
        generatedBy: String,
        confidence: Double,
        version: Int
    ) {
        self.id = id
        self.requestId = requestId
        self.title = title
        self.content = content
        self.sections = sections
        self.metadata = metadata
        self.generatedAt = generatedAt
        self.generatedBy = generatedBy
        self.confidence = confidence
        self.version = version
    }

    static func from(_ document: PRDDocument) -> PRDDocumentDTO {
        return PRDDocumentDTO(
            id: document.id,
            requestId: document.requestId,
            title: document.title,
            content: document.content,
            sections: document.sections.map(PRDSectionDTO.from),
            metadata: DocumentMetadataDTO.from(document.metadata),
            generatedAt: document.generatedAt,
            generatedBy: document.generatedBy,
            confidence: document.confidence,
            version: document.version
        )
    }
}