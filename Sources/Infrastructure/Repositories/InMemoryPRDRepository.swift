import Foundation
import Domain

/// In-memory implementation of PRD repository for testing/development without database
public final class InMemoryPRDRepository: PRDRepositoryProtocol, @unchecked Sendable {
    private var storage: [UUID: PRDRequest] = [:]
    private let queue = DispatchQueue(label: "inmemory.prd.repository", attributes: .concurrent)

    public init() {}

    public func save(_ request: PRDRequest) async throws -> PRDRequest {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async(flags: .barrier) {
                self.storage[request.id] = request
                continuation.resume(returning: request)
            }
        }
    }

    public func findById(_ id: UUID) async throws -> PRDRequest? {
        return await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.storage[id])
            }
        }
    }

    public func findByRequesterId(_ requesterId: String, limit: Int, offset: Int) async throws -> [PRDRequest] {
        return await withCheckedContinuation { continuation in
            queue.async {
                let filtered = self.storage.values
                    .filter { $0.requester.id == requesterId }
                    .sorted { $0.createdAt > $1.createdAt }

                let startIndex = min(offset, filtered.count)
                let endIndex = min(startIndex + limit, filtered.count)
                let result = Array(filtered[startIndex..<endIndex])

                continuation.resume(returning: result)
            }
        }
    }

    public func update(_ request: PRDRequest) async throws -> PRDRequest {
        guard storage[request.id] != nil else {
            throw DomainError.notFound("PRD request with ID \(request.id)")
        }

        return try await save(request)
    }

    public func delete(_ id: UUID) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async(flags: .barrier) {
                if self.storage.removeValue(forKey: id) == nil {
                    continuation.resume(throwing: DomainError.notFound("PRD request with ID \(id)"))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    public func findByStatus(_ status: RequestStatus) async throws -> [PRDRequest] {
        return await withCheckedContinuation { continuation in
            queue.async {
                let filtered = self.storage.values
                    .filter { $0.status == status }
                    .sorted { $0.createdAt > $1.createdAt }

                continuation.resume(returning: Array(filtered))
            }
        }
    }

    public func countByStatus(_ status: RequestStatus) async throws -> Int {
        return await withCheckedContinuation { continuation in
            queue.async {
                let count = self.storage.values
                    .filter { $0.status == status }
                    .count

                continuation.resume(returning: count)
            }
        }
    }
}