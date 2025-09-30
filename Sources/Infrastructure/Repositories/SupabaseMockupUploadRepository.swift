import Foundation
import AsyncHTTPClient
import Domain

public final class SupabaseMockupUploadRepository: MockupUploadRepositoryProtocol {
    private let httpClient: SupabaseHTTPClient
    private let requestBuilder: SupabaseRequestBuilder
    private let tableName: String

    public init(httpClient: HTTPClient, supabaseURL: String, apiKey: String, schema: String = "public") {
        self.httpClient = SupabaseHTTPClient(httpClient: httpClient, supabaseURL: supabaseURL, apiKey: apiKey)
        self.requestBuilder = SupabaseRequestBuilder(supabaseURL: supabaseURL, apiKey: apiKey, schema: schema)
        self.tableName = "mockup_uploads"
    }

    public func save(_ upload: MockupUpload) async throws -> MockupUpload {
        let supabaseModel = try SupabaseMockupUploadModel.from(domainEntity: upload)
        let httpRequest = try requestBuilder.buildInsertRequest(tableName: tableName, model: supabaseModel)
        let savedModels: [SupabaseMockupUploadModel] = try await httpClient.execute(httpRequest)
        let savedModel = try SupabaseResponseMapper.mapSingleResult(savedModels)
        return try savedModel.toDomainEntity()
    }

    public func findById(_ id: UUID) async throws -> MockupUpload? {
        let httpRequest = requestBuilder.buildFindByIdRequest(tableName: tableName, id: id)
        let models: [SupabaseMockupUploadModel] = try await httpClient.execute(httpRequest)
        return try SupabaseResponseMapper.mapOptionalResult(models)?.toDomainEntity()
    }

    public func findByRequestId(_ requestId: UUID) async throws -> [MockupUpload] {
        let httpRequest = requestBuilder.buildFindByFieldRequest(
            tableName: tableName,
            field: "prd_request_id",
            value: requestId.uuidString,
            orderBy: "uploaded_at"
        )
        let models: [SupabaseMockupUploadModel] = try await httpClient.execute(httpRequest)
        return try models.map { try $0.toDomainEntity() }
    }

    public func findExpired() async throws -> [MockupUpload] {
        let now = ISO8601DateFormatter().string(from: Date())
        let httpRequest = requestBuilder.buildFindByFieldRequest(
            tableName: tableName,
            field: "expires_at",
            value: now,
            comparison: "lt",
            orderBy: "expires_at"
        )
        let models: [SupabaseMockupUploadModel] = try await httpClient.execute(httpRequest)
        return try models.map { try $0.toDomainEntity() }
    }

    public func findUnprocessedByRequestId(_ requestId: UUID) async throws -> [MockupUpload] {
        let httpRequest = requestBuilder.buildFindByMultipleFieldsRequest(
            tableName: tableName,
            filters: [
                ("prd_request_id", requestId.uuidString, "eq"),
                ("is_processed", "false", "eq")
            ],
            orderBy: "uploaded_at"
        )
        let models: [SupabaseMockupUploadModel] = try await httpClient.execute(httpRequest)
        return try models.map { try $0.toDomainEntity() }
    }

    public func update(_ upload: MockupUpload) async throws -> MockupUpload {
        let supabaseModel = try SupabaseMockupUploadModel.from(domainEntity: upload)
        let httpRequest = try requestBuilder.buildUpdateRequest(tableName: tableName, id: upload.id, model: supabaseModel)
        let updatedModels: [SupabaseMockupUploadModel] = try await httpClient.execute(httpRequest)
        let updatedModel = try SupabaseResponseMapper.mapSingleResult(updatedModels)
        return try updatedModel.toDomainEntity()
    }

    public func delete(_ id: UUID) async throws {
        let httpRequest = requestBuilder.buildDeleteRequest(tableName: tableName, id: id)
        try await httpClient.executeDelete(httpRequest)
    }

    public func deleteByRequestId(_ requestId: UUID) async throws {
        let httpRequest = requestBuilder.buildDeleteByFieldRequest(
            tableName: tableName,
            field: "prd_request_id",
            value: requestId.uuidString
        )
        try await httpClient.executeDelete(httpRequest)
    }

    public func countByRequestId(_ requestId: UUID) async throws -> Int {
        let httpRequest = requestBuilder.buildCountRequest(
            tableName: tableName,
            field: "prd_request_id",
            value: requestId.uuidString
        )
        return try await httpClient.executeCount(httpRequest)
    }

    public func markAsProcessed(requestId: UUID) async throws {
        let uploads = try await findByRequestId(requestId)
        for upload in uploads {
            let processedUpload = upload.markAsProcessed()
            _ = try await update(processedUpload)
        }
    }
}