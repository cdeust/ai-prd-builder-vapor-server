import Foundation

public struct MockupSourceData: Codable {
    let type: String
    let url: String?
    let localPath: String?
    let content: String?
}