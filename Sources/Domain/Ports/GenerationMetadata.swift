import Foundation

public struct GenerationMetadata {
    public let provider: String
    public let modelVersion: String?
    public let processingTime: TimeInterval
    public let tokensUsed: Int?
    public let cost: Double?

    public init(
        provider: String,
        modelVersion: String? = nil,
        processingTime: TimeInterval,
        tokensUsed: Int? = nil,
        cost: Double? = nil
    ) {
        self.provider = provider
        self.modelVersion = modelVersion
        self.processingTime = processingTime
        self.tokensUsed = tokensUsed
        self.cost = cost
    }
}