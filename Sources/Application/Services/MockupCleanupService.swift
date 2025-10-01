import Foundation
import Domain

public final class MockupCleanupService: Sendable {
    private let storagePort: MockupStoragePort
    private let uploadRepository: MockupUploadRepositoryProtocol

    public init(
        storagePort: MockupStoragePort,
        uploadRepository: MockupUploadRepositoryProtocol
    ) {
        self.storagePort = storagePort
        self.uploadRepository = uploadRepository
    }

    /// Clean up expired mockups (scheduled job)
    public func cleanupExpiredMockups() async throws -> CleanupResult {
        print("[MockupCleanupService] Starting cleanup of expired mockups")

        let expiredUploads = try await uploadRepository.findExpired()
        var deletedCount = 0
        var failedCount = 0
        var reclaimedBytes: Int64 = 0

        for upload in expiredUploads {
            do {
                try await storagePort.delete(path: upload.storagePath)
                try await uploadRepository.delete(upload.id)
                deletedCount += 1
                reclaimedBytes += upload.fileSize
                print("[MockupCleanupService] Deleted expired mockup: \(upload.id)")
            } catch {
                failedCount += 1
                print("[MockupCleanupService] Failed to delete mockup \(upload.id): \(error)")
            }
        }

        let result = CleanupResult(
            totalProcessed: expiredUploads.count,
            deletedCount: deletedCount,
            failedCount: failedCount,
            reclaimedBytes: reclaimedBytes
        )

        print("[MockupCleanupService] Cleanup completed: \(result)")
        return result
    }

    /// Clean up orphaned mockups (no associated PRD request)
    public func cleanupOrphanedMockups() async throws -> CleanupResult {
        print("[MockupCleanupService] Starting cleanup of orphaned mockups")

        // This would require a more complex query to find mockups where prd_request_id doesn't exist
        // For now, we'll rely on cascade deletion from the database
        // The foreign key constraint ON DELETE CASCADE handles this automatically

        return CleanupResult(
            totalProcessed: 0,
            deletedCount: 0,
            failedCount: 0,
            reclaimedBytes: 0
        )
    }

    /// Delete all mockups for a completed PRD request
    public func cleanupForCompletedRequest(requestId: UUID) async throws -> CleanupResult {
        print("[MockupCleanupService] Cleaning up mockups for request: \(requestId)")

        let uploads = try await uploadRepository.findByRequestId(requestId)
        var deletedCount = 0
        var failedCount = 0
        var reclaimedBytes: Int64 = 0

        for upload in uploads {
            do {
                try await storagePort.delete(path: upload.storagePath)
                try await uploadRepository.delete(upload.id)
                deletedCount += 1
                reclaimedBytes += upload.fileSize
            } catch {
                failedCount += 1
                print("[MockupCleanupService] Failed to delete mockup \(upload.id): \(error)")
            }
        }

        let result = CleanupResult(
            totalProcessed: uploads.count,
            deletedCount: deletedCount,
            failedCount: failedCount,
            reclaimedBytes: reclaimedBytes
        )

        print("[MockupCleanupService] Cleanup for request \(requestId) completed: \(result)")
        return result
    }

    /// Verify storage integrity (find mismatches between database and storage)
    public func verifyStorageIntegrity() async throws -> IntegrityReport {
        print("[MockupCleanupService] Verifying storage integrity")

        // Note: This is a basic implementation. A production version would need pagination
        // and more sophisticated logic to handle large datasets

        var missingInStorage: [UUID] = []
        var totalChecked = 0

        // This is a placeholder - in production you'd want to check all uploads
        // For now, we'll check recent uploads only
        let recentUploads = try await uploadRepository.findExpired() // This gets recent ones

        for upload in recentUploads {
            totalChecked += 1
            let exists = try await storagePort.exists(path: upload.storagePath)
            if !exists {
                missingInStorage.append(upload.id)
                print("[MockupCleanupService] Mockup missing in storage: \(upload.id) at \(upload.storagePath)")
            }
        }

        let report = IntegrityReport(
            totalChecked: totalChecked,
            missingInStorage: missingInStorage.count,
            missingUploads: missingInStorage
        )

        print("[MockupCleanupService] Integrity check completed: \(report)")
        return report
    }

    /// Repair integrity issues by removing database entries for missing files
    public func repairIntegrityIssues() async throws -> CleanupResult {
        print("[MockupCleanupService] Repairing integrity issues")

        let report = try await verifyStorageIntegrity()
        var deletedCount = 0
        var failedCount = 0

        for uploadId in report.missingUploads {
            do {
                try await uploadRepository.delete(uploadId)
                deletedCount += 1
                print("[MockupCleanupService] Removed orphaned database entry: \(uploadId)")
            } catch {
                failedCount += 1
                print("[MockupCleanupService] Failed to remove database entry \(uploadId): \(error)")
            }
        }

        let result = CleanupResult(
            totalProcessed: report.missingUploads.count,
            deletedCount: deletedCount,
            failedCount: failedCount,
            reclaimedBytes: 0
        )

        print("[MockupCleanupService] Repair completed: \(result)")
        return result
    }

    /// Get storage statistics
    public func getStorageStatistics() async throws -> StorageStatistics {
        // This would need to be implemented with proper aggregation queries
        // For now, returning a placeholder
        return StorageStatistics(
            totalMockups: 0,
            totalBytes: 0,
            processedMockups: 0,
            unprocessedMockups: 0,
            expiredMockups: 0
        )
    }
}
