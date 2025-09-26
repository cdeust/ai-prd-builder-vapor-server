import Foundation
import Domain

/// In-memory implementation of PRD document repository for testing/development without database
public actor InMemoryPRDDocumentRepository: PRDDocumentRepositoryProtocol {
    private var storage: [UUID: PRDDocument] = [:]

    public init() {}

    public func save(_ document: PRDDocument) async throws -> PRDDocument {
        storage[document.id] = document
        return document
    }

    public func findById(_ id: UUID) async throws -> PRDDocument? {
        return storage[id]
    }

    public func findByRequestId(_ requestId: UUID) async throws -> PRDDocument? {
        return storage.values
            .filter { $0.requestId == requestId }
            .sorted { $0.version > $1.version }
            .first
    }

    public func update(_ document: PRDDocument) async throws -> PRDDocument {
        guard storage[document.id] != nil else {
            throw DomainError.notFound("PRD document with ID \(document.id)")
        }

        return try await save(document)
    }

    public func delete(_ id: UUID) async throws {
        if storage.removeValue(forKey: id) == nil {
            throw DomainError.notFound("PRD document with ID \(id)")
        }
    }
}
