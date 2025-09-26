import Foundation
import Vapor
import FluentKit
import Domain

public final class VaporPRDRepository: PRDRepositoryProtocol {
    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    public func save(_ request: PRDRequest) async throws -> PRDRequest {
        let model = try PRDRequestModel.from(domainEntity: request)
        try await model.save(on: database)
        return try model.toDomainEntity()
    }

    public func findById(_ id: UUID) async throws -> PRDRequest? {
        guard let model = try await PRDRequestModel.find(id, on: database) else {
            return nil
        }
        return try model.toDomainEntity()
    }

    public func findByRequesterId(_ requesterId: String, limit: Int, offset: Int) async throws -> [PRDRequest] {
        let models = try await PRDRequestModel.query(on: database)
            .filter(\.$requesterId == requesterId)
            .sort(\.$createdAt, .descending)
            .limit(limit)
            .offset(offset)
            .all()

        return try models.map { try $0.toDomainEntity() }
    }

    public func update(_ request: PRDRequest) async throws -> PRDRequest {
        guard let model = try await PRDRequestModel.find(request.id, on: database) else {
            throw DomainError.notFound("PRD request with ID \(request.id)")
        }

        model.update(from: request)
        try await model.save(on: database)
        return try model.toDomainEntity()
    }

    public func delete(_ id: UUID) async throws {
        guard let model = try await PRDRequestModel.find(id, on: database) else {
            throw DomainError.notFound("PRD request with ID \(id)")
        }

        try await model.delete(on: database)
    }

    public func findByStatus(_ status: RequestStatus) async throws -> [PRDRequest] {
        let models = try await PRDRequestModel.query(on: database)
            .filter(\.$status == status.rawValue)
            .sort(\.$createdAt, .descending)
            .all()

        return try models.map { try $0.toDomainEntity() }
    }

    public func countByStatus(_ status: RequestStatus) async throws -> Int {
        try await PRDRequestModel.query(on: database)
            .filter(\.$status == status.rawValue)
            .count()
    }
}