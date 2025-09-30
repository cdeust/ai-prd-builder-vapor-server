import Foundation
import AsyncHTTPClient
import NIOCore
import Domain

struct ColorSchemeResponse: Codable {
    let primary: [String]
    let accent: [String]
    let text: [String]
    let background: [String]
}
