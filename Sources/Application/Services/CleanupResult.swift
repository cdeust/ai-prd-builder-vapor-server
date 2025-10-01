import Foundation
import Domain

public struct CleanupResult: Sendable, CustomStringConvertible {
    public let totalProcessed: Int
    public let deletedCount: Int
    public let failedCount: Int
    public let reclaimedBytes: Int64

    public var description: String {
        """
        Processed: \(totalProcessed), Deleted: \(deletedCount), Failed: \(failedCount), Reclaimed: \(formatBytes(reclaimedBytes))
        """
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let mb = Double(bytes) / (1024 * 1024)
        return String(format: "%.2f MB", mb)
    }

    public init(totalProcessed: Int, deletedCount: Int, failedCount: Int, reclaimedBytes: Int64) {
        self.totalProcessed = totalProcessed
        self.deletedCount = deletedCount
        self.failedCount = failedCount
        self.reclaimedBytes = reclaimedBytes
    }
}
