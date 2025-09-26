import Foundation

struct SupabaseDocumentMetadataData: Codable {
    let format: String
    let language: String
    let wordCount: Int
    let estimatedReadTime: Int
    let tags: [String]
    let attachments: [String]
}