import Foundation
import AsyncHTTPClient
import NIOCore
import Domain

struct BoundsResponse: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}
