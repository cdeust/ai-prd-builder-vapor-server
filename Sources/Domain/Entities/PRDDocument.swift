import Foundation

public struct PRDDocument: Sendable {
    public let id: UUID
    public let requestId: UUID
    public let title: String
    public let content: String
    public let sections: [PRDSection]
    public let metadata: DocumentMetadata
    public let generatedAt: Date
    public let generatedBy: String
    public let confidence: Double
    public let version: Int
    public let professionalAnalysis: ProfessionalAnalysis?

    public init(
        id: UUID = UUID(),
        requestId: UUID,
        title: String,
        content: String,
        sections: [PRDSection] = [],
        metadata: DocumentMetadata = DocumentMetadata(),
        generatedAt: Date = Date(),
        generatedBy: String,
        confidence: Double,
        version: Int = 1,
        professionalAnalysis: ProfessionalAnalysis? = nil
    ) {
        self.id = id
        self.requestId = requestId
        self.title = title
        self.content = content
        self.sections = sections
        self.metadata = metadata
        self.generatedAt = generatedAt
        self.generatedBy = generatedBy
        self.confidence = confidence
        self.version = version
        self.professionalAnalysis = professionalAnalysis
    }
}

extension PRDDocument {
    /// Calculate estimated read time based on word count
    public static func estimateReadTime(wordCount: Int) -> Int {
        let wordsPerMinute = 200
        return max(1, wordCount / wordsPerMinute)
    }

    /// Validate document completeness
    public func validate() throws {
        guard !title.isEmpty else {
            throw DomainError.validation("Document title is required")
        }

        guard !content.isEmpty else {
            throw DomainError.validation("Document content is required")
        }

        guard confidence >= 0 && confidence <= 1 else {
            throw DomainError.validation("Confidence must be between 0 and 1")
        }

        // Business rule: Low confidence documents need review
        if confidence < 0.7 && !metadata.tags.contains("needs-review") {
            throw DomainError.businessRule("Low confidence documents must be tagged for review")
        }
    }

    /// Check if document needs human review based on business rules
    public var needsReview: Bool {
        confidence < 0.7 ||
        metadata.tags.contains("needs-review") ||
        (professionalAnalysis?.hasCriticalIssues ?? false)
    }
}