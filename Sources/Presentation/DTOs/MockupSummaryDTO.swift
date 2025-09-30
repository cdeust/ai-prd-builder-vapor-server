import Foundation
import Vapor

public struct MockupSummaryDTO: Content {
    let id: String
    let fileName: String
    let fileSize: Int64
    let uploadedAt: Date
    let isAnalyzed: Bool
    let analysisConfidence: Double?
    let isProcessed: Bool
}
