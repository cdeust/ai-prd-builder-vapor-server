import Foundation
import Vapor

/// DTO for requirements analysis requests
public struct AnalyzeRequirementsRequestDTO: Content {
    public let description: String
    public let mockupSources: [MockupSourceDTO]?

    public init(description: String, mockupSources: [MockupSourceDTO]? = nil) {
        self.description = description
        self.mockupSources = mockupSources
    }
}
