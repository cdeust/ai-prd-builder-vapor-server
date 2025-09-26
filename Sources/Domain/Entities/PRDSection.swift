import Foundation

public struct PRDSection: Sendable {
    public let id: UUID
    public let title: String
    public let content: String
    public let order: Int
    public let sectionType: SectionType

    public init(
        id: UUID = UUID(),
        title: String,
        content: String,
        order: Int,
        sectionType: SectionType
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.order = order
        self.sectionType = sectionType
    }
}