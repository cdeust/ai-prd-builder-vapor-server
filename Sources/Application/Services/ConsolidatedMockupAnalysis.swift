import Foundation
import Domain

public struct ConsolidatedMockupAnalysis: Sendable {
    public let totalMockups: Int
    public let analyzedMockups: Int
    public let uiElements: [String]
    public let userFlows: [UserFlow]
    public let businessLogicInferences: [BusinessLogicInference]
    public let extractedText: [String]
    public let averageConfidence: Double

    public init(
        totalMockups: Int,
        analyzedMockups: Int,
        uiElements: [String],
        userFlows: [UserFlow],
        businessLogicInferences: [BusinessLogicInference],
        extractedText: [String],
        averageConfidence: Double
    ) {
        self.totalMockups = totalMockups
        self.analyzedMockups = analyzedMockups
        self.uiElements = uiElements
        self.userFlows = userFlows
        self.businessLogicInferences = businessLogicInferences
        self.extractedText = extractedText
        self.averageConfidence = averageConfidence
    }
}
