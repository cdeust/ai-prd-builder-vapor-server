import Foundation
import Domain

/// In-memory implementation of PRD document repository for testing/development without database
public final class InMemoryPRDDocumentRepository: PRDDocumentRepositoryProtocol, @unchecked Sendable {
    private var storage: [UUID: PRDDocument] = [:]
    private let queue = DispatchQueue(label: "inmemory.document.repository", attributes: .concurrent)

    public init() {}

    public func save(_ document: PRDDocument) async throws -> PRDDocument {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async(flags: .barrier) {
                self.storage[document.id] = document
                continuation.resume(returning: document)
            }
        }
    }

    public func findById(_ id: UUID) async throws -> PRDDocument? {
        return await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: self.storage[id])
            }
        }
    }

    public func findByRequestId(_ requestId: UUID) async throws -> PRDDocument? {
        return await withCheckedContinuation { continuation in
            queue.async {
                let filtered = self.storage.values
                    .filter { $0.requestId == requestId }
                    .sorted { $0.version > $1.version }
                    .first

                continuation.resume(returning: filtered)
            }
        }
    }

    public func update(_ document: PRDDocument) async throws -> PRDDocument {
        guard storage[document.id] != nil else {
            throw DomainError.notFound("PRD document with ID \(document.id)")
        }

        return try await save(document)
    }

    public func delete(_ id: UUID) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async(flags: .barrier) {
                if self.storage.removeValue(forKey: id) == nil {
                    continuation.resume(throwing: DomainError.notFound("PRD document with ID \(id)"))
                } else {
                    continuation.resume()
                }
            }
        }
    }
}