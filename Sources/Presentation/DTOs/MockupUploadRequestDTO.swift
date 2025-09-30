import Foundation
import Vapor

public struct MockupUploadRequestDTO: Content {
    let requestId: String
    let fileName: String
    let mimeType: String
    let imageData: String // base64 encoded
}
