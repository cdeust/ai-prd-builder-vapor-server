import Foundation
import AsyncHTTPClient
import Domain

public final class SupabasePRDDocumentRepository: PRDDocumentRepositoryProtocol {
    private let httpClient: SupabaseHTTPClient
    private let requestBuilder: SupabaseRequestBuilder
    private let tableName: String

    public init(httpClient: HTTPClient, supabaseURL: String, apiKey: String, schema: String = "public") {
        self.httpClient = SupabaseHTTPClient(httpClient: httpClient, supabaseURL: supabaseURL, apiKey: apiKey)
        self.requestBuilder = SupabaseRequestBuilder(supabaseURL: supabaseURL, apiKey: apiKey, schema: schema)
        self.tableName = "prd_documents"
    }

    public func save(_ document: PRDDocument) async throws -> PRDDocument {
        let supabaseModel = try SupabasePRDDocumentModel.from(domainEntity: document)
        let httpRequest = try requestBuilder.buildInsertRequest(tableName: tableName, model: supabaseModel)
        let savedModels: [SupabasePRDDocumentModel] = try await httpClient.execute(httpRequest)
        let savedModel = try SupabaseResponseMapper.mapSingleResult(savedModels)
        return try savedModel.toDomainEntity()
    }

    public func findById(_ id: UUID) async throws -> PRDDocument? {
        let httpRequest = requestBuilder.buildFindByIdRequest(tableName: tableName, id: id)
        let models: [SupabasePRDDocumentModel] = try await httpClient.execute(httpRequest)
        return try SupabaseResponseMapper.mapOptionalResult(models)?.toDomainEntity()
    }

    public func findByRequestId(_ requestId: UUID) async throws -> PRDDocument? {
        let httpRequest = requestBuilder.buildFindByFieldRequest(tableName: tableName, field: "request_id", value: requestId.uuidString)
        let models: [SupabasePRDDocumentModel] = try await httpClient.execute(httpRequest)
        return try SupabaseResponseMapper.mapOptionalResult(models)?.toDomainEntity()
    }

    public func update(_ document: PRDDocument) async throws -> PRDDocument {
        let supabaseModel = try SupabasePRDDocumentModel.from(domainEntity: document)
        let httpRequest = try requestBuilder.buildUpdateRequest(tableName: tableName, id: document.id, model: supabaseModel)
        let updatedModels: [SupabasePRDDocumentModel] = try await httpClient.execute(httpRequest)
        let updatedModel = try SupabaseResponseMapper.mapSingleResult(updatedModels)
        return try updatedModel.toDomainEntity()
    }

    public func delete(_ id: UUID) async throws {
        let httpRequest = requestBuilder.buildDeleteRequest(tableName: tableName, id: id)
        try await httpClient.executeDelete(httpRequest)
    }
}