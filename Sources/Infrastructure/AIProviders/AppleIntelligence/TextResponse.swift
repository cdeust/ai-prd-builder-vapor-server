import Foundation
import AsyncHTTPClient
import NIOCore
import Domain

struct TextResponse: Codable {
    let content: String
    let category: String
    let bounds: BoundsResponse
}
