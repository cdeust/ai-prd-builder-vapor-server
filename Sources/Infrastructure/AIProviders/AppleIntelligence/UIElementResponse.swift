import Foundation
import AsyncHTTPClient
import NIOCore
import Domain

struct UIElementResponse: Codable {
    let type: String
    let label: String?
    let bounds: BoundsResponse
    let confidence: Double
}
