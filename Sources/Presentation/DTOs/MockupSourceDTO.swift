import Foundation
import Vapor

/// DTO for mockup sources
public struct MockupSourceDTO: Content {
    public let type: String
    public let url: String?
    public let localPath: String?
    public let content: String?

    public init(type: String, url: String? = nil, localPath: String? = nil, content: String? = nil) {
        self.type = type
        self.url = url
        self.localPath = localPath
        self.content = content
    }
}
