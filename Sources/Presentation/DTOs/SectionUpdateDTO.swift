import Foundation
import Vapor
import Domain

public struct SectionUpdateDTO: Content {
    public let id: String
    public let title: String
    public let content: String
    public let order: Int

    public init(id: String, title: String, content: String, order: Int) {
        self.id = id
        self.title = title
        self.content = content
        self.order = order
    }
}
