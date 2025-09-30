import Foundation

/// Protocol for PRD repository - defines the contract for data persistence
/// Following Interface Segregation Principle with focused methods
public protocol PRDRepositoryProtocol: Sendable {
    func save(_ request: PRDRequest) async throws -> PRDRequest
    func findById(_ id: UUID) async throws -> PRDRequest?
    func findByRequesterId(_ requesterId: String, limit: Int, offset: Int) async throws -> [PRDRequest]
    func update(_ request: PRDRequest) async throws -> PRDRequest
    func delete(_ id: UUID) async throws
    func findByStatus(_ status: RequestStatus) async throws -> [PRDRequest]
    func countByStatus(_ status: RequestStatus) async throws -> Int
}

/// Protocol for PRD document storage
public protocol PRDDocumentRepositoryProtocol: Sendable {
    func save(_ document: PRDDocument) async throws -> PRDDocument
    func findById(_ id: UUID) async throws -> PRDDocument?
    func findByRequestId(_ requestId: UUID) async throws -> PRDDocument?
    func update(_ document: PRDDocument) async throws -> PRDDocument
    func delete(_ id: UUID) async throws
}