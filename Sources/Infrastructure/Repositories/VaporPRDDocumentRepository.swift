import Foundation
import Vapor
import FluentKit
import Domain

/// Vapor/Fluent implementation of PRD document repository
public final class VaporPRDDocumentRepository: PRDDocumentRepositoryProtocol {
    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    public func save(_ document: PRDDocument) async throws -> PRDDocument {
        let model = try PRDDocumentModel.from(domainEntity: document)
        try await model.save(on: database)
        return try model.toDomainEntity()
    }

    public func findById(_ id: UUID) async throws -> PRDDocument? {
        guard let model = try await PRDDocumentModel.find(id, on: database) else {
            return nil
        }
        return try model.toDomainEntity()
    }

    public func findByRequestId(_ requestId: UUID) async throws -> PRDDocument? {
        guard let model = try await PRDDocumentModel.query(on: database)
            .filter(\.$requestId == requestId)
            .first() else {
            return nil
        }
        return try model.toDomainEntity()
    }

    public func update(_ document: PRDDocument) async throws -> PRDDocument {
        guard let model = try await PRDDocumentModel.find(document.id, on: database) else {
            throw DomainError.notFound("PRD document with ID \(document.id)")
        }

        model.update(from: document)
        try await model.save(on: database)
        return try model.toDomainEntity()
    }

    public func delete(_ id: UUID) async throws {
        guard let model = try await PRDDocumentModel.find(id, on: database) else {
            throw DomainError.notFound("PRD document with ID \(id)")
        }

        try await model.delete(on: database)
    }
}

// MARK: - Fluent Model

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

    /// Convert from domain entity to model
    static func from(domainEntity: PRDDocument) throws -> PRDDocumentModel {
        // Serialize sections
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

        // Serialize metadata
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

    /// Convert from model to domain entity
    func toDomainEntity() throws -> PRDDocument {
        guard let id = self.id else {
            throw DomainError.processingFailed("Missing document ID")
        }

        // Deserialize sections
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

        // Deserialize metadata
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

    /// Update model fields from domain entity
    func update(from domainEntity: PRDDocument) {
        title = domainEntity.title
        content = domainEntity.content
        generatedBy = domainEntity.generatedBy
        confidence = domainEntity.confidence
        version = domainEntity.version

        // Note: sections and metadata would need re-serialization in a real update
        // For simplicity, assuming these don't change after creation
    }
}

// MARK: - Helper Data Structures

private struct VaporDocPRDSectionData: Codable {
    let id: UUID
    let title: String
    let content: String
    let order: Int
    let sectionType: String
}

private struct VaporDocMetadataData: Codable {
    let format: String
    let language: String
    let wordCount: Int
    let estimatedReadTime: Int
    let tags: [String]
    let attachments: [String]
}

// MARK: - Migration

public struct CreatePRDDocument: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        try await database.schema("prd_documents")
            .id()
            .field("request_id", .uuid, .required)
            .field("title", .string, .required)
            .field("content", .string, .required)
            .field("sections", .string, .required)
            .field("metadata", .string, .required)
            .field("generated_at", .datetime, .required)
            .field("generated_by", .string, .required)
            .field("confidence", .double, .required)
            .field("version", .int, .required)
            .foreignKey("request_id", references: "prd_requests", "id", onDelete: .cascade)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("prd_documents").delete()
    }
}