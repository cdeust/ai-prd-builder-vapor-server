import Foundation
import AsyncHTTPClient
import NIOCore
import Domain

struct VisionAnalysisRequest: Codable {
    let imageURL: String
    let prompt: String
    let features: [String]
}
