import Foundation
import FluentKit
import Domain

final class PRDDocumentModel: Model, @unchecked Sendable {
    static let schema = "prd_documents"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "request_id")
    var requestId: UUID

    @Field(key: "title")
    var title: String

    @Field(key: "content")
    var content: String

    @Field(key: "sections")
    var sectionsJSON: String

    @Field(key: "metadata")
    var metadataJSON: String

    @Field(key: "generated_at")
    var generatedAt: Date

    @Field(key: "generated_by")
    var generatedBy: String

    @Field(key: "confidence")
    var confidence: Double

    @Field(key: "version")
    var version: Int

    init() { }

    init(
        id: UUID? = nil,
        requestId: UUID,
        title: String,
        content: String,
        sectionsJSON: String,
        metadataJSON: String,
        generatedAt: Date,
        generatedBy: String,
        confidence: Double,
        version: Int
    ) {
        self.id = id
        self.requestId = requestId
        self.title = title
        self.content = content
        self.sectionsJSON = sectionsJSON
        self.metadataJSON = metadataJSON
        self.generatedAt = generatedAt
        self.generatedBy = generatedBy
        self.confidence = confidence
        self.version = version
    }

    static func from(domainEntity: PRDDocument) throws -> PRDDocumentModel {
        let sectionsData = try JSONEncoder().encode(domainEntity.sections.map { section in
            VaporDocPRDSectionData(
                id: section.id,
                title: section.title,
                content: section.content,
                order: section.order,
                sectionType: section.sectionType.rawValue
            )
        })

        guard let sectionsJSON = String(data: sectionsData, encoding: .utf8) else {
            throw DomainError.processingFailed("Failed to serialize sections")
        }

        let metadataData = try JSONEncoder().encode(VaporDocMetadataData(
            format: domainEntity.metadata.format.rawValue,
            language: domainEntity.metadata.language,
            wordCount: domainEntity.metadata.wordCount,
            estimatedReadTime: domainEntity.metadata.estimatedReadTime,
            tags: domainEntity.metadata.tags,
            attachments: domainEntity.metadata.attachments
        ))

        guard let metadataJSON = String(data: metadataData, encoding: .utf8) else {
            throw DomainError.processingFailed("Failed to serialize metadata")
        }

        return PRDDocumentModel(
            id: domainEntity.id,
            requestId: domainEntity.requestId,
            title: domainEntity.title,
            content: domainEntity.content,
            sectionsJSON: sectionsJSON,
            metadataJSON: metadataJSON,
            generatedAt: domainEntity.generatedAt,
            generatedBy: domainEntity.generatedBy,
            confidence: domainEntity.confidence,
            version: domainEntity.version
        )
    }

    func toDomainEntity() throws -> PRDDocument {
        guard let id = self.id else {
            throw DomainError.processingFailed("Missing document ID")
        }

        guard let sectionsData = sectionsJSON.data(using: .utf8) else {
            throw DomainError.processingFailed("Invalid sections JSON")
        }

        let sectionsDataArray = try JSONDecoder().decode([VaporDocPRDSectionData].self, from: sectionsData)
        let sections = sectionsDataArray.map { data in
            PRDSection(
                id: data.id,
                title: data.title,
                content: data.content,
                order: data.order,
                sectionType: SectionType(rawValue: data.sectionType) ?? .appendix
            )
        }

        guard let metadataData = metadataJSON.data(using: .utf8) else {
            throw DomainError.processingFailed("Invalid metadata JSON")
        }

        let metadataDataStruct = try JSONDecoder().decode(VaporDocMetadataData.self, from: metadataData)
        let metadata = DocumentMetadata(
            format: DocumentFormat(rawValue: metadataDataStruct.format) ?? .markdown,
            language: metadataDataStruct.language,
            wordCount: metadataDataStruct.wordCount,
            estimatedReadTime: metadataDataStruct.estimatedReadTime,
            tags: metadataDataStruct.tags,
            attachments: metadataDataStruct.attachments
        )

        return PRDDocument(
            id: id,
            requestId: requestId,
            title: title,
            content: content,
            sections: sections,
            metadata: metadata,
            generatedAt: generatedAt,
            generatedBy: generatedBy,
            confidence: confidence,
            version: version
        )
    }

    func update(from domainEntity: PRDDocument) {
        title = domainEntity.title
        content = domainEntity.content
        generatedBy = domainEntity.generatedBy
        confidence = domainEntity.confidence
        version = domainEntity.version
    }
}