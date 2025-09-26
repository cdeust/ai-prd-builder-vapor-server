import Foundation
import Domain

struct SupabasePRDDocumentModel: Codable {
    let id: UUID
    let request_id: UUID
    let title: String
    let content: String
    let sections: String
    let metadata: String
    let generated_at: String
    let generated_by: String
    let confidence: Double
    let version: Int

    static func from(domainEntity: PRDDocument) throws -> SupabasePRDDocumentModel {
        let sectionsData = try JSONEncoder().encode(domainEntity.sections.map { section in
            SupabasePRDSectionData(
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

        let metadataData = try JSONEncoder().encode(SupabaseDocumentMetadataData(
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

        let iso8601Formatter = ISO8601DateFormatter()

        return SupabasePRDDocumentModel(
            id: domainEntity.id,
            request_id: domainEntity.requestId,
            title: domainEntity.title,
            content: domainEntity.content,
            sections: sectionsJSON,
            metadata: metadataJSON,
            generated_at: iso8601Formatter.string(from: domainEntity.generatedAt),
            generated_by: domainEntity.generatedBy,
            confidence: domainEntity.confidence,
            version: domainEntity.version
        )
    }

    func toDomainEntity() throws -> PRDDocument {
        let iso8601Formatter = ISO8601DateFormatter()

        guard let generatedAt = iso8601Formatter.date(from: generated_at) else {
            throw DomainError.processingFailed("Invalid date format in Supabase document data")
        }

        guard let sectionsData = sections.data(using: .utf8) else {
            throw DomainError.processingFailed("Invalid sections JSON")
        }

        let sectionsDataArray = try JSONDecoder().decode([SupabasePRDSectionData].self, from: sectionsData)
        let prdSections = sectionsDataArray.map { data in
            PRDSection(
                id: data.id,
                title: data.title,
                content: data.content,
                order: data.order,
                sectionType: SectionType(rawValue: data.sectionType) ?? .appendix
            )
        }

        guard let metadataData = metadata.data(using: .utf8) else {
            throw DomainError.processingFailed("Invalid metadata JSON")
        }

        let metadataDataStruct = try JSONDecoder().decode(SupabaseDocumentMetadataData.self, from: metadataData)
        let documentMetadata = DocumentMetadata(
            format: DocumentFormat(rawValue: metadataDataStruct.format) ?? .markdown,
            language: metadataDataStruct.language,
            wordCount: metadataDataStruct.wordCount,
            estimatedReadTime: metadataDataStruct.estimatedReadTime,
            tags: metadataDataStruct.tags,
            attachments: metadataDataStruct.attachments
        )

        return PRDDocument(
            id: id,
            requestId: request_id,
            title: title,
            content: content,
            sections: prdSections,
            metadata: documentMetadata,
            generatedAt: generatedAt,
            generatedBy: generated_by,
            confidence: confidence,
            version: version
        )
    }
}