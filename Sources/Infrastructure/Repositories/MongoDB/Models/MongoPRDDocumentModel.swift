import Foundation
import Domain

public struct MongoPRDDocumentModel: Codable {
    let _id: String
    let request_id: String
    let title: String
    let content: String
    let sections: [PRDSectionData]
    let metadata: DocumentMetadataData
    let generated_at: Date
    let generated_by: String
    let confidence: Double
    let version: Int
    let word_count: Int
    let tags: [String]
    let search_text: String

    static func from(domainEntity: PRDDocument) throws -> MongoPRDDocumentModel {
        let sections = domainEntity.sections.map { section in
            PRDSectionData(
                id: section.id,
                title: section.title,
                content: section.content,
                order: section.order,
                sectionType: section.sectionType.rawValue
            )
        }

        let metadata = DocumentMetadataData(
            format: domainEntity.metadata.format.rawValue,
            language: domainEntity.metadata.language,
            wordCount: domainEntity.metadata.wordCount,
            estimatedReadTime: domainEntity.metadata.estimatedReadTime,
            tags: domainEntity.metadata.tags,
            attachments: domainEntity.metadata.attachments
        )

        let searchText = [
            domainEntity.title,
            domainEntity.content,
            domainEntity.sections.map { $0.title + " " + $0.content }.joined(separator: " ")
        ].joined(separator: " ")

        return MongoPRDDocumentModel(
            _id: domainEntity.id.uuidString,
            request_id: domainEntity.requestId.uuidString,
            title: domainEntity.title,
            content: domainEntity.content,
            sections: sections,
            metadata: metadata,
            generated_at: domainEntity.generatedAt,
            generated_by: domainEntity.generatedBy,
            confidence: domainEntity.confidence,
            version: domainEntity.version,
            word_count: domainEntity.metadata.wordCount,
            tags: domainEntity.metadata.tags,
            search_text: searchText
        )
    }

    func toDomainEntity() throws -> PRDDocument {
        guard let id = UUID(uuidString: _id),
              let requestId = UUID(uuidString: request_id) else {
            throw DomainError.processingFailed("Invalid UUID format in MongoDB document data")
        }

        let prdSections = sections.map { data in
            PRDSection(
                id: data.id,
                title: data.title,
                content: data.content,
                order: data.order,
                sectionType: SectionType(rawValue: data.sectionType) ?? .appendix
            )
        }

        let documentMetadata = DocumentMetadata(
            format: DocumentFormat(rawValue: metadata.format) ?? .markdown,
            language: metadata.language,
            wordCount: metadata.wordCount,
            estimatedReadTime: metadata.estimatedReadTime,
            tags: metadata.tags,
            attachments: metadata.attachments
        )

        return PRDDocument(
            id: id,
            requestId: requestId,
            title: title,
            content: content,
            sections: prdSections,
            metadata: documentMetadata,
            generatedAt: generated_at,
            generatedBy: generated_by,
            confidence: confidence,
            version: version
        )
    }
}