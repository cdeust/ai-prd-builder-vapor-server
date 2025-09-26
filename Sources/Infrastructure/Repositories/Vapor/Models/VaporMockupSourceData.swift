import Foundation

struct VaporMockupSourceData: Codable {
    let type: String
    let url: String?
    let localPath: String?
    let content: String?
}