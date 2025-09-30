import Foundation
import Vapor

public struct StorageStatsDTO: Content {
    let totalMockups: Int
    let totalBytes: Int64
    let processedMockups: Int
    let unprocessedMockups: Int
    let expiredMockups: Int
}
