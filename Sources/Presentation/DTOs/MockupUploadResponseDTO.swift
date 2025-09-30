import Foundation
import Vapor

public struct MockupUploadResponseDTO: Content {
    let id: String
    let requestId: String
    let fileName: String
    let fileSize: Int64
    let mimeType: String
    let uploadedAt: Date
    let isProcessed: Bool
    let expiresAt: Date
}
