import Foundation

public struct DocumentMetadata: Sendable {
    public let format: DocumentFormat
    public let language: String
    public let wordCount: Int
    public let estimatedReadTime: Int
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