import Foundation

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
