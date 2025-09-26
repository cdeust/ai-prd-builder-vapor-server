import Foundation
import Vapor

/// DTO for error responses
public struct ErrorResponseDTO: Content {
    public let error: ErrorDetailDTO

    public init(error: ErrorDetailDTO) {
        self.error = error
    }
}