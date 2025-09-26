import Foundation
import Vapor

/// DTO for PRD request lists
public struct PRDRequestListResponseDTO: Content {
    public let requests: [PRDRequestSummaryDTO]
    public let pagination: PaginationDTO

    public init(requests: [PRDRequestSummaryDTO], pagination: PaginationDTO) {
        self.requests = requests
        self.pagination = pagination
    }
}