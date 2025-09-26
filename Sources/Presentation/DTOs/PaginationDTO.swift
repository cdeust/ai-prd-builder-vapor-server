import Foundation
import Vapor

/// DTO for pagination metadata
public struct PaginationDTO: Content {
    public let limit: Int
    public let offset: Int
    public let total: Int

    public init(limit: Int, offset: Int, total: Int) {
        self.limit = limit
        self.offset = offset
        self.total = total
    }
}