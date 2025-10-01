import Foundation
import Domain

public struct StorageStatistics: Sendable {
    public let totalMockups: Int
    public let totalBytes: Int64
    public let processedMockups: Int
    public let unprocessedMockups: Int
    public let expiredMockups: Int

    public init(
        totalMockups: Int,
        totalBytes: Int64,
        processedMockups: Int,
        unprocessedMockups: Int,
        expiredMockups: Int
    ) {
        self.totalMockups = totalMockups
        self.totalBytes = totalBytes
        self.processedMockups = processedMockups
        self.unprocessedMockups = unprocessedMockups
        self.expiredMockups = expiredMockups
    }
}
