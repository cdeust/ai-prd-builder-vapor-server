import Foundation
import Vapor

/// DTO for error details
public struct ErrorDetailDTO: Content {
    public let code: String
    public let message: String
    public let timestamp: Date

    public init(code: String, message: String, timestamp: Date) {
        self.code = code
        self.message = message
        self.timestamp = timestamp
    }
}