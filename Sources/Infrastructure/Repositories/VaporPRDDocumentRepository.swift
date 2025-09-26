import Foundation
import Vapor
import FluentKit
import Domain

public final class VaporPRDDocumentRepository: PRDDocumentRepositoryProtocol {
    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    public func save(_ document: PRDDocument) async throws -> PRDDocument {
        let model = try PRDDocumentModel.from(domainEntity: document)
        try await model.save(on: database)
        return try model.toDomainEntity()
    }

    public func findById(_ id: UUID) async throws -> PRDDocument? {
        guard let model = try await PRDDocumentModel.find(id, on: database) else {
            return nil
        }
        return try model.toDomainEntity()
    }

    public func findByRequestId(_ requestId: UUID) async throws -> PRDDocument? {
        guard let model = try await PRDDocumentModel.query(on: database)
            .filter(\.$requestId == requestId)
            .first() else {
            return nil
        }
        return try model.toDomainEntity()
    }

    public func update(_ document: PRDDocument) async throws -> PRDDocument {
        guard let model = try await PRDDocumentModel.find(document.id, on: database) else {
            throw DomainError.notFound("PRD document with ID \(document.id)")
        }

        model.update(from: document)
        try await model.save(on: database)
        return try model.toDomainEntity()
    }

    public func delete(_ id: UUID) async throws {
        guard let model = try await PRDDocumentModel.find(id, on: database) else {
            throw DomainError.notFound("PRD document with ID \(id)")
        }

        try await model.delete(on: database)
    }
}