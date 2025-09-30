import Foundation

public protocol MockupUploadRepositoryProtocol: Sendable {
    /// Save a new mockup upload record
    /// - Parameter upload: Mockup upload entity
    /// - Returns: Saved mockup upload with generated ID
    func save(_ upload: MockupUpload) async throws -> MockupUpload

    /// Find mockup upload by ID
    /// - Parameter id: Upload ID
    /// - Returns: Mockup upload if found
    func findById(_ id: UUID) async throws -> MockupUpload?

    /// Find all mockup uploads for a specific PRD request
    /// - Parameter requestId: PRD request ID
    /// - Returns: Array of mockup uploads
    func findByRequestId(_ requestId: UUID) async throws -> [MockupUpload]

    /// Find expired mockup uploads
    /// - Returns: Array of expired mockup uploads
    func findExpired() async throws -> [MockupUpload]

    /// Find unprocessed mockup uploads for a request
    /// - Parameter requestId: PRD request ID
    /// - Returns: Array of unprocessed mockup uploads
    func findUnprocessedByRequestId(_ requestId: UUID) async throws -> [MockupUpload]

    /// Update mockup upload
    /// - Parameter upload: Mockup upload entity
    /// - Returns: Updated mockup upload
    func update(_ upload: MockupUpload) async throws -> MockupUpload

    /// Delete mockup upload by ID
    /// - Parameter id: Upload ID
    func delete(_ id: UUID) async throws

    /// Delete all mockup uploads for a specific request
    /// - Parameter requestId: PRD request ID
    func deleteByRequestId(_ requestId: UUID) async throws

    /// Count mockup uploads for a specific request
    /// - Parameter requestId: PRD request ID
    /// - Returns: Count of mockup uploads
    func countByRequestId(_ requestId: UUID) async throws -> Int

    /// Mark mockup uploads as processed
    /// - Parameter requestId: PRD request ID
    func markAsProcessed(requestId: UUID) async throws
}