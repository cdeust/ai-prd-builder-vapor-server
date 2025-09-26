import Foundation
import Domain

struct SupabasePRDRequestModel: Codable {
    let id: UUID
    let title: String
    let description: String
    let mockup_sources: String
    let priority: String
    let preferred_provider: String?
    let requester_id: String
    let status: String
    let created_at: String
    let updated_at: String
    let completed_at: String?
    let generated_document_id: UUID?

    static func from(domainEntity: PRDRequest) throws -> SupabasePRDRequestModel {
        let mockupSourcesData = try JSONEncoder().encode(domainEntity.mockupSources.map { mockup in
            SupabaseMockupSourceData(
                type: mockup.type.rawValue,
                url: mockup.url?.absoluteString,
                localPath: mockup.location,
                content: nil
            )
        })

        guard let mockupSourcesJSON = String(data: mockupSourcesData, encoding: .utf8) else {
            throw DomainError.processingFailed("Failed to serialize mockup sources")
        }

        let iso8601Formatter = ISO8601DateFormatter()

        return SupabasePRDRequestModel(
            id: domainEntity.id,
            title: domainEntity.title,
            description: domainEntity.description,
            mockup_sources: mockupSourcesJSON,
            priority: domainEntity.priority.rawValue,
            preferred_provider: nil,
            requester_id: domainEntity.requester.id,
            status: domainEntity.status.rawValue,
            created_at: iso8601Formatter.string(from: domainEntity.createdAt),
            updated_at: iso8601Formatter.string(from: Date()),
            completed_at: nil,
            generated_document_id: nil
        )
    }

    func toDomainEntity() throws -> PRDRequest {
        let iso8601Formatter = ISO8601DateFormatter()

        guard let createdAt = iso8601Formatter.date(from: created_at),
              let _ = iso8601Formatter.date(from: updated_at) else {
            throw DomainError.processingFailed("Invalid date format in Supabase data")
        }

        guard let mockupSourcesData = mockup_sources.data(using: .utf8) else {
            throw DomainError.processingFailed("Invalid mockup sources JSON")
        }

        let mockupSourcesDataArray = try JSONDecoder().decode([SupabaseMockupSourceData].self, from: mockupSourcesData)
        let mockupSources = mockupSourcesDataArray.compactMap { data in
            let mockupType = MockupType(rawValue: data.type) ?? MockupType.url
            let location = data.url ?? data.localPath ?? data.content ?? ""
            return try? MockupSource(
                type: mockupType,
                location: location,
                metadata: nil
            )
        }

        return PRDRequest(
            id: id,
            title: title,
            description: description,
            mockupSources: mockupSources,
            priority: Priority(rawValue: priority) ?? .medium,
            requester: Requester(id: requester_id),
            metadata: RequestMetadata(),
            createdAt: createdAt,
            status: RequestStatus.from(rawValue: status)
        )
    }
}