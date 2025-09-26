import Foundation
import Domain

/// In-memory implementation of PRD repository for testing/development without database
public actor InMemoryPRDRepository: PRDRepositoryProtocol {
    private var storage: [UUID: PRDRequest] = [:]

    public init() {}

    public func save(_ request: PRDRequest) async throws -> PRDRequest {
        storage[request.id] = request
        return request
    }

    public func findById(_ id: UUID) async throws -> PRDRequest? {
        return storage[id]
    }

    public func findByRequesterId(_ requesterId: String, limit: Int, offset: Int) async throws -> [PRDRequest] {
        let filtered = storage.values
            .filter { $0.requester.id == requesterId }
            .sorted { $0.createdAt > $1.createdAt }

        let startIndex = min(offset, filtered.count)
        let endIndex = min(startIndex + limit, filtered.count)
        return Array(filtered[startIndex..<endIndex])
    }

    public func update(_ request: PRDRequest) async throws -> PRDRequest {
        guard storage[request.id] != nil else {
            throw DomainError.notFound("PRD request with ID \(request.id)")
        }

        return try await save(request)
    }

    public func delete(_ id: UUID) async throws {
        if storage.removeValue(forKey: id) == nil {
            throw DomainError.notFound("PRD request with ID \(id)")
        }
    }

    public func findByStatus(_ status: RequestStatus) async throws -> [PRDRequest] {
        return storage.values
            .filter { $0.status.rawValue == status.rawValue }
            .sorted { $0.createdAt > $1.createdAt }
    }

    public func countByStatus(_ status: RequestStatus) async throws -> Int {
        return storage.values
            .filter { $0.status.rawValue == status.rawValue }
            .count
    }
}