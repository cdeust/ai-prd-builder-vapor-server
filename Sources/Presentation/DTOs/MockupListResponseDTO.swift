import Foundation
import Vapor

public struct MockupListResponseDTO: Content {
    let requestId: String
    let totalCount: Int
    let mockups: [MockupSummaryDTO]
}
