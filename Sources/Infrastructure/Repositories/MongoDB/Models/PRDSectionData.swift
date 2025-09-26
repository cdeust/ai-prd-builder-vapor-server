import Foundation

public struct PRDSectionData: Codable {
    let id: UUID
    let title: String
    let content: String
    let order: Int
    let sectionType: String
}