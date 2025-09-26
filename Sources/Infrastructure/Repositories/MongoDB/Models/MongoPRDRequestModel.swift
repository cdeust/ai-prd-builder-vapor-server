import Foundation
import Domain

public struct MongoPRDRequestModel: Codable {
    let _id: String
    let title: String
    let description: String
    let mockup_sources: [MockupSourceData]
    let priority: String
    let preferred_provider: String?
    let requester_id: String
    let status: String
    let created_at: Date
    let updated_at: Date
    let completed_at: Date?
    let generated_document_id: String?

    static func from(domainEntity: PRDRequest) throws -> MongoPRDRequestModel {
        return MongoPRDRequestModel(
            _id: domainEntity.id.uuidString,
            title: domainEntity.title,
            description: domainEntity.description,
            mockup_sources: domainEntity.mockupSources.map { mockup in
                MockupSourceData(
                    type: mockup.type.rawValue,
                    url: mockup.url?.absoluteString,
                    localPath: mockup.location,
                    content: nil
                )
            },
            priority: domainEntity.priority.rawValue,
            preferred_provider: nil,
            requester_id: domainEntity.requester.id,
            status: domainEntity.status.rawValue,
            created_at: domainEntity.createdAt,
            updated_at: Date(),
            completed_at: nil,
            generated_document_id: nil
        )
    }

    func toDomainEntity() throws -> PRDRequest {
        guard let id = UUID(uuidString: _id) else {
            throw DomainError.processingFailed("Invalid UUID format in MongoDB data: \(_id)")
        }

        let mockupSources = mockup_sources.compactMap { data in
            let mockupType: MockupType = MockupType(rawValue: data.type) ?? MockupType.url
            let location = data.url ?? data.localPath ?? data.content ?? ""
            return try? MockupSource(
                type: mockupType,
                location: location,
                metadata: nil
            )
        }

        let requester = Requester(id: requester_id)

        return PRDRequest(
            id: id,
            title: title,
            description: description,
            mockupSources: mockupSources,
            priority: Priority(rawValue: priority) ?? .medium,
            requester: requester,
            metadata: RequestMetadata(),
            createdAt: created_at,
            status: RequestStatus.from(rawValue: status)
        )
    }
}