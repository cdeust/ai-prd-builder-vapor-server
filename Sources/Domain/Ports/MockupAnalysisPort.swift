import Foundation

public protocol MockupAnalysisPort: Sendable {
    /// Analyze a mockup image using AI
    /// - Parameters:
    ///   - imageURL: URL to the mockup image
    ///   - context: Additional context about the PRD request
    /// - Returns: Analysis result with confidence score
    func analyzeMockup(
        imageURL: String,
        context: MockupAnalysisContext
    ) async throws -> (result: MockupAnalysisResult, confidence: Double)

    /// Batch analyze multiple mockups
    /// - Parameters:
    ///   - imageURLs: Array of image URLs
    ///   - context: Additional context about the PRD request
    /// - Returns: Array of analysis results
    func analyzeMockups(
        imageURLs: [String],
        context: MockupAnalysisContext
    ) async throws -> [(result: MockupAnalysisResult, confidence: Double)]

    /// Check if the analysis service is available
    /// - Returns: True if service is operational
    func isAvailable() async -> Bool
}

public struct MockupAnalysisContext: Sendable {
    public let requestTitle: String
    public let requestDescription: String
    public let existingMockupAnalyses: [MockupAnalysisResult]

    public init(
        requestTitle: String,
        requestDescription: String,
        existingMockupAnalyses: [MockupAnalysisResult] = []
    ) {
        self.requestTitle = requestTitle
        self.requestDescription = requestDescription
        self.existingMockupAnalyses = existingMockupAnalyses
    }
}