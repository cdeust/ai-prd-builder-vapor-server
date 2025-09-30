import Foundation

public struct MockupAnalysisResult: Sendable, Codable, Equatable {
    public let uiElements: [UIElement]
    public let layoutStructure: LayoutStructure
    public let extractedText: [ExtractedText]
    public let colorScheme: ColorScheme?
    public let inferredUserFlows: [UserFlow]
    public let businessLogicInferences: [BusinessLogicInference]
    public let analyzedAt: Date

    public init(
        uiElements: [UIElement],
        layoutStructure: LayoutStructure,
        extractedText: [ExtractedText],
        colorScheme: ColorScheme? = nil,
        inferredUserFlows: [UserFlow],
        businessLogicInferences: [BusinessLogicInference],
        analyzedAt: Date = Date()
    ) {
        self.uiElements = uiElements
        self.layoutStructure = layoutStructure
        self.extractedText = extractedText
        self.colorScheme = colorScheme
        self.inferredUserFlows = inferredUserFlows
        self.businessLogicInferences = businessLogicInferences
        self.analyzedAt = analyzedAt
    }
}
