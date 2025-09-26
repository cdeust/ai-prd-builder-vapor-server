import Foundation

struct SupabasePRDSectionData: Codable {
    let id: UUID
    let title: String
    let content: String
    let order: Int
    let sectionType: String
}