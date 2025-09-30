import Foundation
import Vapor

public struct CleanupResultDTO: Content {
    let totalProcessed: Int
    let deletedCount: Int
    let failedCount: Int
    let reclaimedBytes: Int64
}
