import Foundation
import Vapor
import FluentKit
import Domain

/// Vapor/Fluent implementation of PRD repository
/// Handles data persistence using Vapor's ORM
public final class VaporPRDRepository: PRDRepositoryProtocol {
    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    public func save(_ request: PRDRequest) async throws -> PRDRequest {
        let model = try PRDRequestModel.from(domainEntity: request)
        try await model.save(on: database)
        return try model.toDomainEntity()
    }

    public func findById(_ id: UUID) async throws -> PRDRequest? {
        guard let model = try await PRDRequestModel.find(id, on: database) else {
            return nil
        }
        return try model.toDomainEntity()
    }

    public func findByRequesterId(_ requesterId: String, limit: Int, offset: Int) async throws -> [PRDRequest] {
        let models = try await PRDRequestModel.query(on: database)
            .filter(\.$requesterId == requesterId)
            .sort(\.$createdAt, .descending)
            .limit(limit)
            .offset(offset)
            .all()

        return try models.map { try $0.toDomainEntity() }
    }

    public func update(_ request: PRDRequest) async throws -> PRDRequest {
        guard let model = try await PRDRequestModel.find(request.id, on: database) else {
            throw DomainError.notFound("PRD request with ID \(request.id)")
        }

        model.update(from: request)
        try await model.save(on: database)
        return try model.toDomainEntity()
    }

    public func delete(_ id: UUID) async throws {
        guard let model = try await PRDRequestModel.find(id, on: database) else {
            throw DomainError.notFound("PRD request with ID \(id)")
        }

        try await model.delete(on: database)
    }

    public func findByStatus(_ status: RequestStatus) async throws -> [PRDRequest] {
        let models = try await PRDRequestModel.query(on: database)
            .filter(\.$status == status.rawValue)
            .sort(\.$createdAt, .descending)
            .all()

        return try models.map { try $0.toDomainEntity() }
    }

    public func countByStatus(_ status: RequestStatus) async throws -> Int {
        try await PRDRequestModel.query(on: database)
            .filter(\.$status == status.rawValue)
            .count()
    }
}

// MARK: - Fluent Model

final class PRDRequestModel: Model, @unchecked Sendable {
    static let schema = "prd_requests"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "title")
    var title: String

    @Field(key: "description")
    var description: String

    @Field(key: "mockup_sources")
    var mockupSourcesJSON: String

    @Field(key: "priority")
    var priority: String

    @OptionalField(key: "preferred_provider")
    var preferredProvider: String?

    @Field(key: "requester_id")
    var requesterId: String

    @Field(key: "status")
    var status: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @OptionalField(key: "completed_at")
    var completedAt: Date?

    @OptionalField(key: "generated_document_id")
    var generatedDocumentId: UUID?

    init() { }

    init(
        id: UUID? = nil,
        title: String,
        description: String,
        mockupSourcesJSON: String,
        priority: String,
        preferredProvider: String? = nil,
        requesterId: String,
        status: String,
        completedAt: Date? = nil,
        generatedDocumentId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.mockupSourcesJSON = mockupSourcesJSON
        self.priority = priority
        self.preferredProvider = preferredProvider
        self.requesterId = requesterId
        self.status = status
        self.completedAt = completedAt
        self.generatedDocumentId = generatedDocumentId
    }

    /// Convert from domain entity to model
    static func from(domainEntity: PRDRequest) throws -> PRDRequestModel {
        let mockupSourcesData = try JSONEncoder().encode(domainEntity.mockupSources.map { mockup in
            VaporMockupSourceData(
                type: mockup.type.rawValue,
                url: mockup.url?.absoluteString,
                localPath: mockup.location,
                content: nil
            )
        })

        guard let mockupSourcesJSON = String(data: mockupSourcesData, encoding: .utf8) else {
            throw DomainError.processingFailed("Failed to serialize mockup sources")
        }

        return PRDRequestModel(
            id: domainEntity.id,
            title: domainEntity.title,
            description: domainEntity.description,
            mockupSourcesJSON: mockupSourcesJSON,
            priority: domainEntity.priority.rawValue,
            preferredProvider: nil,
            requesterId: domainEntity.requester.id,
            status: domainEntity.status.rawValue,
            completedAt: nil,
            generatedDocumentId: nil
        )
    }

    /// Convert from model to domain entity
    func toDomainEntity() throws -> PRDRequest {
        guard let id = self.id,
              let createdAt = self.createdAt,
              let updatedAt = self.updatedAt else {
            throw DomainError.processingFailed("Missing required model fields")
        }

        // Deserialize mockup sources
        guard let mockupSourcesData = mockupSourcesJSON.data(using: .utf8) else {
            throw DomainError.processingFailed("Invalid mockup sources JSON")
        }

        let mockupSourcesDataArray = try JSONDecoder().decode([VaporMockupSourceData].self, from: mockupSourcesData)
        let mockupSources: [MockupSource] = mockupSourcesDataArray.compactMap { (data: VaporMockupSourceData) -> MockupSource? in
            let mockupType: MockupType = MockupType(rawValue: data.type) ?? MockupType.url
            let location: String = data.url ?? data.localPath ?? data.content ?? ""
            return try? MockupSource(
                type: mockupType,
                location: location,
                metadata: nil
            )
        }

        let requester = Requester(id: requesterId)
        return PRDRequest(
            id: id,
            title: title,
            description: description,
            mockupSources: mockupSources,
            priority: Priority(rawValue: priority) ?? .medium,
            requester: requester,
            metadata: RequestMetadata(),
            createdAt: createdAt ?? Date(),
            status: RequestStatus.from(rawValue: status)
        )
    }

    /// Update model fields from domain entity
    func update(from domainEntity: PRDRequest) {
        title = domainEntity.title
        description = domainEntity.description
        priority = domainEntity.priority.rawValue
        preferredProvider = nil
        status = domainEntity.status.rawValue
        completedAt = nil
        generatedDocumentId = nil
    }
}

// MARK: - Helper Data Structures

private struct VaporMockupSourceData: Codable {
    let type: String
    let url: String?
    let localPath: String?
    let content: String?
}

// MARK: - Migration

public struct CreatePRDRequest: AsyncMigration {
    public init() {}

    public func prepare(on database: Database) async throws {
        try await database.schema("prd_requests")
            .id()
            .field("title", .string, .required)
            .field("description", .string, .required)
            .field("mockup_sources", .string, .required)
            .field("priority", .string, .required)
            .field("preferred_provider", .string)
            .field("requester_id", .string, .required)
            .field("status", .string, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .field("completed_at", .datetime)
            .field("generated_document_id", .uuid)
            .create()
    }

    public func revert(on database: Database) async throws {
        try await database.schema("prd_requests").delete()
    }
}