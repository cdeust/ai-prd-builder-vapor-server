import Foundation

struct SupabaseMockupSourceData: Codable {
    let type: String
    let url: String?
    let localPath: String?
    let content: String?
}