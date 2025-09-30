import Foundation
import MongoSwift
import Domain

public final class MongoPRDDocumentRepository: PRDDocumentRepositoryProtocol, @unchecked Sendable {
    private let collection: MongoCollection<MongoPRDDocumentModel>

    public init(database: MongoDatabase) {
        self.collection = database.collection("prd_documents", withType: MongoPRDDocumentModel.self)
    }

    public func save(_ document: PRDDocument) async throws -> PRDDocument {
        let mongoModel = try MongoPRDDocumentModel.from(domainEntity: document)
        do {
            _ = try await collection.insertOne(mongoModel)
            return document
        } catch {
            throw DomainError.processingFailed("MongoDB document save error: \(error.localizedDescription)")
        }
    }

    public func findById(_ id: UUID) async throws -> PRDDocument? {
        let filter = MongoQueryBuilder.buildRequestFilter(id: id)
        do {
            guard let mongoModel = try await collection.findOne(filter) else { return nil }
            return try mongoModel.toDomainEntity()
        } catch {
            throw DomainError.processingFailed("MongoDB document findById error: \(error.localizedDescription)")
        }
    }

    public func findByRequestId(_ requestId: UUID) async throws -> PRDDocument? {
        let filter: BSONDocument = ["request_id": .string(requestId.uuidString)]
        do {
            guard let mongoModel = try await collection.findOne(filter) else { return nil }
            return try mongoModel.toDomainEntity()
        } catch {
            throw DomainError.processingFailed("MongoDB document findByRequestId error: \(error.localizedDescription)")
        }
    }

    public func update(_ document: PRDDocument) async throws -> PRDDocument {
        let filter = MongoQueryBuilder.buildRequestFilter(id: document.id)
        let mongoModel = try MongoPRDDocumentModel.from(domainEntity: document)
        do {
            let update = try MongoQueryBuilder.buildUpdateDocument(mongoModel)
            let result = try await collection.updateOne(filter: filter, update: update)
            try MongoResultMapper.mapUpdateResult(result, entityId: document.id, entityType: "PRD document")
            return document
        } catch let error as DomainError {
            throw error
        } catch {
            throw DomainError.processingFailed("MongoDB document update error: \(error.localizedDescription)")
        }
    }

    public func delete(_ id: UUID) async throws {
        let filter = MongoQueryBuilder.buildRequestFilter(id: id)
        do {
            let result = try await collection.deleteOne(filter)
            try MongoResultMapper.mapDeleteResult(result, entityId: id, entityType: "PRD document")
        } catch let error as DomainError {
            throw error
        } catch {
            throw DomainError.processingFailed("MongoDB document delete error: \(error.localizedDescription)")
        }
    }
}