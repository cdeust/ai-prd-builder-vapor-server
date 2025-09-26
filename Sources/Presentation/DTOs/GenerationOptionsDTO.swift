import Foundation
import Vapor

/// DTO for generation options
public struct GenerationOptionsDTO: Content {
    public let includeTestCases: Bool?
    public let includeApiSpec: Bool?
    public let includeTechnicalDetails: Bool?
    public let maxSections: Int?
    public let targetAudience: String?
    public let customPrompt: String?

    public init(
        includeTestCases: Bool? = nil,
        includeApiSpec: Bool? = nil,
        includeTechnicalDetails: Bool? = nil,
        maxSections: Int? = nil,
        targetAudience: String? = nil,
        customPrompt: String? = nil
    ) {
        self.includeTestCases = includeTestCases
        self.includeApiSpec = includeApiSpec
        self.includeTechnicalDetails = includeTechnicalDetails
        self.maxSections = maxSections
        self.targetAudience = targetAudience
        self.customPrompt = customPrompt
    }
}
