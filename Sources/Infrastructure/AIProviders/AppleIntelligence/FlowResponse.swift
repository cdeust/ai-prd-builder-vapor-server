import Foundation
import AsyncHTTPClient
import NIOCore
import Domain

struct FlowResponse: Codable {
    let name: String
    let steps: [String]
    let confidence: Double?
}
