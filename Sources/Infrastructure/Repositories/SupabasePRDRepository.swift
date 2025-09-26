import Foundation
import AsyncHTTPClient
import Domain

/// Supabase implementation of PRD repository
/// Uses Supabase REST API for data persistence with real-time subscriptions
public final class SupabasePRDRepository: PRDRepositoryProtocol {
    private let httpClient: HTTPClient
    private let supabaseURL: String
    private let apiKey: String
    private let tableName = "prd_requests"

    public init(httpClient: HTTPClient, supabaseURL: String, apiKey: String) {
        self.httpClient = httpClient
        self.supabaseURL = supabaseURL.hasSuffix("/") ? String(supabaseURL.dropLast()) : supabaseURL
        self.apiKey = apiKey
    }

    public func save(_ request: PRDRequest) async throws -> PRDRequest {
        let supabaseModel = try SupabasePRDRequestModel.from(domainEntity: request)
        let requestData = try JSONEncoder().encode(supabaseModel)

        var httpRequest = HTTPClientRequest(url: "\(supabaseURL)/rest/v1/\(tableName)")
        httpRequest.method = .POST
        httpRequest.headers.add(name: "Content-Type", value: "application/json")
        httpRequest.headers.add(name: "apikey", value: apiKey)
        httpRequest.headers.add(name: "Authorization", value: "Bearer \(apiKey)")
        httpRequest.headers.add(name: "Prefer", value: "return=representation")
        httpRequest.body = .bytes(requestData)

        let response = try await httpClient.execute(httpRequest, timeout: .seconds(30))

        guard response.status.code >= 200 && response.status.code < 300 else {
            let errorBody = try await response.body.collect(upTo: 1024 * 1024)
            let errorMessage = String(buffer: errorBody)
            throw DomainError.processingFailed("Supabase save error: \(response.status) - \(errorMessage)")
        }

        let responseBody = try await response.body.collect(upTo: 10 * 1024 * 1024)
        let savedModels = try JSONDecoder().decode([SupabasePRDRequestModel].self, from: responseBody)

        guard let savedModel = savedModels.first else {
            throw DomainError.processingFailed("No data returned from Supabase save operation")
        }

        return try savedModel.toDomainEntity()
    }

    public func findById(_ id: UUID) async throws -> PRDRequest? {
        var httpRequest = HTTPClientRequest(url: "\(supabaseURL)/rest/v1/\(tableName)?id=eq.\(id.uuidString)&select=*")
        httpRequest.method = .GET
        httpRequest.headers.add(name: "apikey", value: apiKey)
        httpRequest.headers.add(name: "Authorization", value: "Bearer \(apiKey)")

        let response = try await httpClient.execute(httpRequest, timeout: .seconds(30))

        guard response.status == .ok else {
            if response.status == .notFound {
                return nil
            }
            let errorBody = try await response.body.collect(upTo: 1024 * 1024)
            let errorMessage = String(buffer: errorBody)
            throw DomainError.processingFailed("Supabase fetch error: \(response.status) - \(errorMessage)")
        }

        let responseBody = try await response.body.collect(upTo: 10 * 1024 * 1024)
        let models = try JSONDecoder().decode([SupabasePRDRequestModel].self, from: responseBody)

        return try models.first?.toDomainEntity()
    }

    public func findByRequesterId(_ requesterId: String, limit: Int, offset: Int) async throws -> [PRDRequest] {
        let encodedRequesterId = requesterId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? requesterId
        let url = "\(supabaseURL)/rest/v1/\(tableName)?requester_id=eq.\(encodedRequesterId)&order=created_at.desc&limit=\(limit)&offset=\(offset)&select=*"

        var httpRequest = HTTPClientRequest(url: url)
        httpRequest.method = .GET
        httpRequest.headers.add(name: "apikey", value: apiKey)
        httpRequest.headers.add(name: "Authorization", value: "Bearer \(apiKey)")

        let response = try await httpClient.execute(httpRequest, timeout: .seconds(30))

        guard response.status == .ok else {
            let errorBody = try await response.body.collect(upTo: 1024 * 1024)
            let errorMessage = String(buffer: errorBody)
            throw DomainError.processingFailed("Supabase query error: \(response.status) - \(errorMessage)")
        }

        let responseBody = try await response.body.collect(upTo: 10 * 1024 * 1024)
        let models = try JSONDecoder().decode([SupabasePRDRequestModel].self, from: responseBody)

        return try models.map { try $0.toDomainEntity() }
    }

    public func update(_ request: PRDRequest) async throws -> PRDRequest {
        let supabaseModel = try SupabasePRDRequestModel.from(domainEntity: request)
        let requestData = try JSONEncoder().encode(supabaseModel)

        var httpRequest = HTTPClientRequest(url: "\(supabaseURL)/rest/v1/\(tableName)?id=eq.\(request.id.uuidString)")
        httpRequest.method = .PATCH
        httpRequest.headers.add(name: "Content-Type", value: "application/json")
        httpRequest.headers.add(name: "apikey", value: apiKey)
        httpRequest.headers.add(name: "Authorization", value: "Bearer \(apiKey)")
        httpRequest.headers.add(name: "Prefer", value: "return=representation")
        httpRequest.body = .bytes(requestData)

        let response = try await httpClient.execute(httpRequest, timeout: .seconds(30))

        guard response.status.code >= 200 && response.status.code < 300 else {
            let errorBody = try await response.body.collect(upTo: 1024 * 1024)
            let errorMessage = String(buffer: errorBody)
            throw DomainError.processingFailed("Supabase update error: \(response.status) - \(errorMessage)")
        }

        let responseBody = try await response.body.collect(upTo: 10 * 1024 * 1024)
        let updatedModels = try JSONDecoder().decode([SupabasePRDRequestModel].self, from: responseBody)

        guard let updatedModel = updatedModels.first else {
            throw DomainError.processingFailed("No data returned from Supabase update operation")
        }

        return try updatedModel.toDomainEntity()
    }

    public func delete(_ id: UUID) async throws {
        var httpRequest = HTTPClientRequest(url: "\(supabaseURL)/rest/v1/\(tableName)?id=eq.\(id.uuidString)")
        httpRequest.method = .DELETE
        httpRequest.headers.add(name: "apikey", value: apiKey)
        httpRequest.headers.add(name: "Authorization", value: "Bearer \(apiKey)")

        let response = try await httpClient.execute(httpRequest, timeout: .seconds(30))

        guard response.status.code >= 200 && response.status.code < 300 else {
            let errorBody = try await response.body.collect(upTo: 1024 * 1024)
            let errorMessage = String(buffer: errorBody)
            throw DomainError.processingFailed("Supabase delete error: \(response.status) - \(errorMessage)")
        }
    }

    public func findByStatus(_ status: RequestStatus) async throws -> [PRDRequest] {
        let url = "\(supabaseURL)/rest/v1/\(tableName)?status=eq.\(status.rawValue)&order=created_at.desc&select=*"

        var httpRequest = HTTPClientRequest(url: url)
        httpRequest.method = .GET
        httpRequest.headers.add(name: "apikey", value: apiKey)
        httpRequest.headers.add(name: "Authorization", value: "Bearer \(apiKey)")

        let response = try await httpClient.execute(httpRequest, timeout: .seconds(30))

        guard response.status == .ok else {
            let errorBody = try await response.body.collect(upTo: 1024 * 1024)
            let errorMessage = String(buffer: errorBody)
            throw DomainError.processingFailed("Supabase status query error: \(response.status) - \(errorMessage)")
        }

        let responseBody = try await response.body.collect(upTo: 10 * 1024 * 1024)
        let models = try JSONDecoder().decode([SupabasePRDRequestModel].self, from: responseBody)

        return try models.map { try $0.toDomainEntity() }
    }

    public func countByStatus(_ status: RequestStatus) async throws -> Int {
        let url = "\(supabaseURL)/rest/v1/\(tableName)?status=eq.\(status.rawValue)&select=count"

        var httpRequest = HTTPClientRequest(url: url)
        httpRequest.method = .GET
        httpRequest.headers.add(name: "apikey", value: apiKey)
        httpRequest.headers.add(name: "Authorization", value: "Bearer \(apiKey)")
        httpRequest.headers.add(name: "Prefer", value: "count=exact")

        let response = try await httpClient.execute(httpRequest, timeout: .seconds(30))

        guard response.status == .ok else {
            let errorBody = try await response.body.collect(upTo: 1024 * 1024)
            let errorMessage = String(buffer: errorBody)
            throw DomainError.processingFailed("Supabase count error: \(response.status) - \(errorMessage)")
        }

        // Extract count from Content-Range header
        if let contentRange = response.headers.first(name: "content-range"),
           let countString = contentRange.split(separator: "/").last,
           let count = Int(countString) {
            return count
        }

        return 0
    }
}

// MARK: - Supabase Document Repository

/// Supabase implementation of PRD document repository
public final class SupabasePRDDocumentRepository: PRDDocumentRepositoryProtocol {
    private let httpClient: HTTPClient
    private let supabaseURL: String
    private let apiKey: String
    private let tableName = "prd_documents"

    public init(httpClient: HTTPClient, supabaseURL: String, apiKey: String) {
        self.httpClient = httpClient
        self.supabaseURL = supabaseURL.hasSuffix("/") ? String(supabaseURL.dropLast()) : supabaseURL
        self.apiKey = apiKey
    }

    public func save(_ document: PRDDocument) async throws -> PRDDocument {
        let supabaseModel = try SupabasePRDDocumentModel.from(domainEntity: document)
        let requestData = try JSONEncoder().encode(supabaseModel)

        var httpRequest = HTTPClientRequest(url: "\(supabaseURL)/rest/v1/\(tableName)")
        httpRequest.method = .POST
        httpRequest.headers.add(name: "Content-Type", value: "application/json")
        httpRequest.headers.add(name: "apikey", value: apiKey)
        httpRequest.headers.add(name: "Authorization", value: "Bearer \(apiKey)")
        httpRequest.headers.add(name: "Prefer", value: "return=representation")
        httpRequest.body = .bytes(requestData)

        let response = try await httpClient.execute(httpRequest, timeout: .seconds(30))

        guard response.status.code >= 200 && response.status.code < 300 else {
            let errorBody = try await response.body.collect(upTo: 1024 * 1024)
            let errorMessage = String(buffer: errorBody)
            throw DomainError.processingFailed("Supabase document save error: \(response.status) - \(errorMessage)")
        }

        let responseBody = try await response.body.collect(upTo: 10 * 1024 * 1024)
        let savedModels = try JSONDecoder().decode([SupabasePRDDocumentModel].self, from: responseBody)

        guard let savedModel = savedModels.first else {
            throw DomainError.processingFailed("No document data returned from Supabase save operation")
        }

        return try savedModel.toDomainEntity()
    }

    public func findById(_ id: UUID) async throws -> PRDDocument? {
        var httpRequest = HTTPClientRequest(url: "\(supabaseURL)/rest/v1/\(tableName)?id=eq.\(id.uuidString)&select=*")
        httpRequest.method = .GET
        httpRequest.headers.add(name: "apikey", value: apiKey)
        httpRequest.headers.add(name: "Authorization", value: "Bearer \(apiKey)")

        let response = try await httpClient.execute(httpRequest, timeout: .seconds(30))

        guard response.status == .ok else {
            if response.status == .notFound {
                return nil
            }
            let errorBody = try await response.body.collect(upTo: 1024 * 1024)
            let errorMessage = String(buffer: errorBody)
            throw DomainError.processingFailed("Supabase document fetch error: \(response.status) - \(errorMessage)")
        }

        let responseBody = try await response.body.collect(upTo: 10 * 1024 * 1024)
        let models = try JSONDecoder().decode([SupabasePRDDocumentModel].self, from: responseBody)

        return try models.first?.toDomainEntity()
    }

    public func findByRequestId(_ requestId: UUID) async throws -> PRDDocument? {
        var httpRequest = HTTPClientRequest(url: "\(supabaseURL)/rest/v1/\(tableName)?request_id=eq.\(requestId.uuidString)&select=*")
        httpRequest.method = .GET
        httpRequest.headers.add(name: "apikey", value: apiKey)
        httpRequest.headers.add(name: "Authorization", value: "Bearer \(apiKey)")

        let response = try await httpClient.execute(httpRequest, timeout: .seconds(30))

        guard response.status == .ok else {
            if response.status == .notFound {
                return nil
            }
            let errorBody = try await response.body.collect(upTo: 1024 * 1024)
            let errorMessage = String(buffer: errorBody)
            throw DomainError.processingFailed("Supabase document query error: \(response.status) - \(errorMessage)")
        }

        let responseBody = try await response.body.collect(upTo: 10 * 1024 * 1024)
        let models = try JSONDecoder().decode([SupabasePRDDocumentModel].self, from: responseBody)

        return try models.first?.toDomainEntity()
    }

    public func update(_ document: PRDDocument) async throws -> PRDDocument {
        let supabaseModel = try SupabasePRDDocumentModel.from(domainEntity: document)
        let requestData = try JSONEncoder().encode(supabaseModel)

        var httpRequest = HTTPClientRequest(url: "\(supabaseURL)/rest/v1/\(tableName)?id=eq.\(document.id.uuidString)")
        httpRequest.method = .PATCH
        httpRequest.headers.add(name: "Content-Type", value: "application/json")
        httpRequest.headers.add(name: "apikey", value: "Bearer \(apiKey)")
        httpRequest.headers.add(name: "Authorization", value: "Bearer \(apiKey)")
        httpRequest.headers.add(name: "Prefer", value: "return=representation")
        httpRequest.body = .bytes(requestData)

        let response = try await httpClient.execute(httpRequest, timeout: .seconds(30))

        guard response.status.code >= 200 && response.status.code < 300 else {
            let errorBody = try await response.body.collect(upTo: 1024 * 1024)
            let errorMessage = String(buffer: errorBody)
            throw DomainError.processingFailed("Supabase document update error: \(response.status) - \(errorMessage)")
        }

        let responseBody = try await response.body.collect(upTo: 10 * 1024 * 1024)
        let updatedModels = try JSONDecoder().decode([SupabasePRDDocumentModel].self, from: responseBody)

        guard let updatedModel = updatedModels.first else {
            throw DomainError.processingFailed("No document data returned from Supabase update operation")
        }

        return try updatedModel.toDomainEntity()
    }

    public func delete(_ id: UUID) async throws {
        var httpRequest = HTTPClientRequest(url: "\(supabaseURL)/rest/v1/\(tableName)?id=eq.\(id.uuidString)")
        httpRequest.method = .DELETE
        httpRequest.headers.add(name: "apikey", value: apiKey)
        httpRequest.headers.add(name: "Authorization", value: "Bearer \(apiKey)")

        let response = try await httpClient.execute(httpRequest, timeout: .seconds(30))

        guard response.status.code >= 200 && response.status.code < 300 else {
            let errorBody = try await response.body.collect(upTo: 1024 * 1024)
            let errorMessage = String(buffer: errorBody)
            throw DomainError.processingFailed("Supabase document delete error: \(response.status) - \(errorMessage)")
        }
    }
}

// MARK: - Supabase Models

/// Supabase model for PRD requests
private struct SupabasePRDRequestModel: Codable {
    let id: UUID
    let title: String
    let description: String
    let mockup_sources: String // JSON string
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
              let updatedAt = iso8601Formatter.date(from: updated_at) else {
            throw DomainError.processingFailed("Invalid date format in Supabase data")
        }

        let completedAtDate = completed_at.flatMap { iso8601Formatter.date(from: $0) }

        // Deserialize mockup sources
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

/// Supabase model for PRD documents
private struct SupabasePRDDocumentModel: Codable {
    let id: UUID
    let request_id: UUID
    let title: String
    let content: String
    let sections: String // JSON string
    let metadata: String // JSON string
    let generated_at: String
    let generated_by: String
    let confidence: Double
    let version: Int

    static func from(domainEntity: PRDDocument) throws -> SupabasePRDDocumentModel {
        // Serialize sections
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

        // Serialize metadata
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

        // Deserialize sections
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

        // Deserialize metadata
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

// MARK: - Helper Data Structures

private struct SupabaseMockupSourceData: Codable {
    let type: String
    let url: String?
    let localPath: String?
    let content: String?
}

private struct SupabasePRDSectionData: Codable {
    let id: UUID
    let title: String
    let content: String
    let order: Int
    let sectionType: String
}

private struct SupabaseDocumentMetadataData: Codable {
    let format: String
    let language: String
    let wordCount: Int
    let estimatedReadTime: Int
    let tags: [String]
    let attachments: [String]
}