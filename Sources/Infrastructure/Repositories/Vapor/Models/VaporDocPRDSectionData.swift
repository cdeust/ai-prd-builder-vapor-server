import Foundation

struct VaporDocPRDSectionData: Codable {
    let id: UUID
    let title: String
    let content: String
    let order: Int
    let sectionType: String
}