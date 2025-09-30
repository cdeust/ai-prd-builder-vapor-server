import Foundation
import Domain

public actor InMemoryMockupUploadRepository: MockupUploadRepositoryProtocol {
    private var uploads: [UUID: MockupUpload] = [:]

    public init() {}

    public func save(_ upload: MockupUpload) async throws -> MockupUpload {
        uploads[upload.id] = upload
        return upload
    }

    public func findById(_ id: UUID) async throws -> MockupUpload? {
        return uploads[id]
    }

    public func findByRequestId(_ requestId: UUID) async throws -> [MockupUpload] {
        return uploads.values.filter { $0.prdRequestId == requestId }
            .sorted { $0.uploadedAt < $1.uploadedAt }
    }

    public func findExpired() async throws -> [MockupUpload] {
        let now = Date()
        return uploads.values.filter { $0.expiresAt < now }
            .sorted { $0.expiresAt < $1.expiresAt }
    }

    public func findUnprocessedByRequestId(_ requestId: UUID) async throws -> [MockupUpload] {
        return uploads.values.filter { $0.prdRequestId == requestId && !$0.isProcessed }
            .sorted { $0.uploadedAt < $1.uploadedAt }
    }

    public func update(_ upload: MockupUpload) async throws -> MockupUpload {
        guard uploads[upload.id] != nil else {
            throw DomainError.notFound("Mockup upload not found: \(upload.id)")
        }
        uploads[upload.id] = upload
        return upload
    }

    public func delete(_ id: UUID) async throws {
        guard uploads[id] != nil else {
            throw DomainError.notFound("Mockup upload not found: \(id)")
        }
        uploads.removeValue(forKey: id)
    }

    public func deleteByRequestId(_ requestId: UUID) async throws {
        let idsToDelete = uploads.values.filter { $0.prdRequestId == requestId }.map { $0.id }
        for id in idsToDelete {
            uploads.removeValue(forKey: id)
        }
    }

    public func countByRequestId(_ requestId: UUID) async throws -> Int {
        return uploads.values.filter { $0.prdRequestId == requestId }.count
    }

    public func markAsProcessed(requestId: UUID) async throws {
        for (id, upload) in uploads where upload.prdRequestId == requestId {
            uploads[id] = upload.markAsProcessed()
        }
    }
}