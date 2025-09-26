import Foundation

/// Domain entity representing a generated PRD document
public struct PRDDocument {
    public let id: UUID
    public let requestId: UUID
    public let title: String
    public let content: String
    public let sections: [PRDSection]
    public let metadata: DocumentMetadata
    public let generatedAt: Date
    public let generatedBy: String // Provider that generated it
    public let confidence: Double
    public let version: Int

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
        version: Int = 1
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
    }
}

public struct PRDSection {
    public let id: UUID
    public let title: String
    public let content: String
    public let order: Int
    public let sectionType: SectionType

    public init(
        id: UUID = UUID(),
        title: String,
        content: String,
        order: Int,
        sectionType: SectionType
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.order = order
        self.sectionType = sectionType
    }
}

public enum SectionType: String, CaseIterable {
    case executiveSummary
    case problemStatement
    case userStories
    case functionalRequirements
    case nonFunctionalRequirements
    case technicalRequirements
    case acceptanceCriteria
    case timeline
    case risks
    case appendix
}

public struct DocumentMetadata {
    public let format: DocumentFormat
    public let language: String
    public let wordCount: Int
    public let estimatedReadTime: Int // in minutes
    public let tags: [String]
    public let attachments: [String]

    public init(
        format: DocumentFormat = .markdown,
        language: String = "en",
        wordCount: Int = 0,
        estimatedReadTime: Int = 0,
        tags: [String] = [],
        attachments: [String] = []
    ) {
        self.format = format
        self.language = language
        self.wordCount = wordCount
        self.estimatedReadTime = estimatedReadTime
        self.tags = tags
        self.attachments = attachments
    }
}

public enum DocumentFormat: String, CaseIterable {
    case markdown
    case html
    case pdf
    case docx
    case json
}

// MARK: - Domain Logic

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
        confidence < 0.7 || metadata.tags.contains("needs-review")
    }
}