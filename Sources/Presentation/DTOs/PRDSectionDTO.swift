import Foundation
import Vapor
import Domain

/// DTO for PRD sections
public struct PRDSectionDTO: Content {
    public let id: UUID
    public let title: String
    public let content: String
    public let order: Int
    public let sectionType: String

    public init(id: UUID, title: String, content: String, order: Int, sectionType: String) {
        self.id = id
        self.title = title
        self.content = content
        self.order = order
        self.sectionType = sectionType
    }

    static func from(_ section: PRDSection) -> PRDSectionDTO {
        return PRDSectionDTO(
            id: section.id,
            title: section.title,
            content: section.content,
            order: section.order,
            sectionType: section.sectionType.rawValue
        )
    }
}