import Foundation
import MongoSwift
import Domain

public final class MongoPRDRepository: PRDRepositoryProtocol {
    private let collection: MongoCollection<MongoPRDRequestModel>

    public init(database: MongoDatabase) {
        self.collection = database.collection("prd_requests", withType: MongoPRDRequestModel.self)
    }

    public func save(_ request: PRDRequest) async throws -> PRDRequest {
        let mongoModel = try MongoPRDRequestModel.from(domainEntity: request)
        do {
            _ = try await collection.insertOne(mongoModel)
            return request
        } catch {
            throw DomainError.processingFailed("MongoDB save error: \(error.localizedDescription)")
        }
    }

    public func findById(_ id: UUID) async throws -> PRDRequest? {
        let filter = MongoQueryBuilder.buildRequestFilter(id: id)
        do {
            guard let mongoModel = try await collection.findOne(filter) else { return nil }
            return try mongoModel.toDomainEntity()
        } catch {
            throw DomainError.processingFailed("MongoDB findById error: \(error.localizedDescription)")
        }
    }

    public func findByRequesterId(_ requesterId: String, limit: Int, offset: Int) async throws -> [PRDRequest] {
        let filter = MongoQueryBuilder.buildRequesterFilter(requesterId: requesterId)
        let options = MongoQueryBuilder.buildFindOptions(limit: limit, offset: offset, sortField: "created_at", ascending: false)
        do {
            let cursor = try await collection.find(filter, options: options)
            return try await MongoResultMapper.mapCursor(cursor) { try $0.toDomainEntity() }
        } catch {
            throw DomainError.processingFailed("MongoDB findByRequesterId error: \(error.localizedDescription)")
        }
    }

    public func update(_ request: PRDRequest) async throws -> PRDRequest {
        let filter = MongoQueryBuilder.buildRequestFilter(id: request.id)
        let mongoModel = try MongoPRDRequestModel.from(domainEntity: request)
        do {
            let update = try MongoQueryBuilder.buildUpdateDocument(mongoModel)
            let result = try await collection.updateOne(filter: filter, update: update)
            try MongoResultMapper.mapUpdateResult(result, entityId: request.id, entityType: "PRD request")
            return request
        } catch let error as DomainError {
            throw error
        } catch {
            throw DomainError.processingFailed("MongoDB update error: \(error.localizedDescription)")
        }
    }

    public func delete(_ id: UUID) async throws {
        let filter = MongoQueryBuilder.buildRequestFilter(id: id)
        do {
            let result = try await collection.deleteOne(filter)
            try MongoResultMapper.mapDeleteResult(result, entityId: id, entityType: "PRD request")
        } catch let error as DomainError {
            throw error
        } catch {
            throw DomainError.processingFailed("MongoDB delete error: \(error.localizedDescription)")
        }
    }

    public func findByStatus(_ status: RequestStatus) async throws -> [PRDRequest] {
        let filter = MongoQueryBuilder.buildStatusFilter(status: status)
        let options = MongoQueryBuilder.buildFindOptions(sortField: "created_at", ascending: false)
        do {
            let cursor = try await collection.find(filter, options: options)
            return try await MongoResultMapper.mapCursor(cursor) { try $0.toDomainEntity() }
        } catch {
            throw DomainError.processingFailed("MongoDB findByStatus error: \(error.localizedDescription)")
        }
    }

    public func countByStatus(_ status: RequestStatus) async throws -> Int {
        let filter = MongoQueryBuilder.buildStatusFilter(status: status)
        do {
            return try await collection.countDocuments(filter)
        } catch {
            throw DomainError.processingFailed("MongoDB countByStatus error: \(error.localizedDescription)")
        }
    }
}