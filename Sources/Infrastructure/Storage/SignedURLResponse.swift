import Foundation
import AsyncHTTPClient
import NIOCore
import Domain

struct SignedURLResponse: Codable {
    let signedURL: String
}
