import Foundation
import FluentKit
import Domain

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

    func toDomainEntity() throws -> PRDRequest {
        guard let id = self.id,
              let createdAt = self.createdAt,
              let _ = self.updatedAt else {
            throw DomainError.processingFailed("Missing required model fields")
        }

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
            createdAt: createdAt,
            status: RequestStatus.from(rawValue: status)
        )
    }

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