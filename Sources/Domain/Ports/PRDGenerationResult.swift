import Foundation

public struct PRDGenerationResult {
    public let content: String
    public let sections: [GeneratedSection]
    public let confidence: Double
    public let metadata: GenerationMetadata

    public init(
        content: String,
        sections: [GeneratedSection],
        confidence: Double,
        metadata: GenerationMetadata
    ) {
        self.content = content
        self.sections = sections
        self.confidence = confidence
        self.metadata = metadata
    }
}