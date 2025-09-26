import Foundation
import AsyncHTTPClient
import Domain

public final class SupabasePRDRepository: PRDRepositoryProtocol {
    private let httpClient: SupabaseHTTPClient
    private let requestBuilder: SupabaseRequestBuilder
    private let tableName = "prd_requests"

    public init(httpClient: HTTPClient, supabaseURL: String, apiKey: String) {
        self.httpClient = SupabaseHTTPClient(httpClient: httpClient, supabaseURL: supabaseURL, apiKey: apiKey)
        self.requestBuilder = SupabaseRequestBuilder(supabaseURL: supabaseURL, apiKey: apiKey)
    }

    public func save(_ request: PRDRequest) async throws -> PRDRequest {
        let supabaseModel = try SupabasePRDRequestModel.from(domainEntity: request)
        let httpRequest = try requestBuilder.buildInsertRequest(tableName: tableName, model: supabaseModel)
        let savedModels: [SupabasePRDRequestModel] = try await httpClient.execute(httpRequest)
        let savedModel = try SupabaseResponseMapper.mapSingleResult(savedModels)
        return try savedModel.toDomainEntity()
    }

    public func findById(_ id: UUID) async throws -> PRDRequest? {
        let httpRequest = requestBuilder.buildFindByIdRequest(tableName: tableName, id: id)
        let models: [SupabasePRDRequestModel] = try await httpClient.execute(httpRequest)
        return try SupabaseResponseMapper.mapOptionalResult(models)?.toDomainEntity()
    }

    public func findByRequesterId(_ requesterId: String, limit: Int, offset: Int) async throws -> [PRDRequest] {
        let httpRequest = requestBuilder.buildFindByFieldRequest(
            tableName: tableName,
            field: "requester_id",
            value: requesterId,
            limit: limit,
            offset: offset,
            orderBy: "created_at"
        )
        let models: [SupabasePRDRequestModel] = try await httpClient.execute(httpRequest)
        return try models.map { try $0.toDomainEntity() }
    }

    public func update(_ request: PRDRequest) async throws -> PRDRequest {
        let supabaseModel = try SupabasePRDRequestModel.from(domainEntity: request)
        let httpRequest = try requestBuilder.buildUpdateRequest(tableName: tableName, id: request.id, model: supabaseModel)
        let updatedModels: [SupabasePRDRequestModel] = try await httpClient.execute(httpRequest)
        let updatedModel = try SupabaseResponseMapper.mapSingleResult(updatedModels)
        return try updatedModel.toDomainEntity()
    }

    public func delete(_ id: UUID) async throws {
        let httpRequest = requestBuilder.buildDeleteRequest(tableName: tableName, id: id)
        try await httpClient.executeDelete(httpRequest)
    }

    public func findByStatus(_ status: RequestStatus) async throws -> [PRDRequest] {
        let httpRequest = requestBuilder.buildFindByFieldRequest(
            tableName: tableName,
            field: "status",
            value: status.rawValue,
            orderBy: "created_at"
        )
        let models: [SupabasePRDRequestModel] = try await httpClient.execute(httpRequest)
        return try models.map { try $0.toDomainEntity() }
    }

    public func countByStatus(_ status: RequestStatus) async throws -> Int {
        let httpRequest = requestBuilder.buildCountRequest(tableName: tableName, field: "status", value: status.rawValue)
        return try await httpClient.executeCount(httpRequest)
    }
}