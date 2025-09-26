import Foundation

public struct MockupAnalysis {
    public let extractedFeatures: [String]
    public let userFlows: [String]
    public let uiComponents: [String]
    public let businessLogic: [String]

    public init(
        extractedFeatures: [String],
        userFlows: [String],
        uiComponents: [String],
        businessLogic: [String]
    ) {
        self.extractedFeatures = extractedFeatures
        self.userFlows = userFlows
        self.uiComponents = uiComponents
        self.businessLogic = businessLogic
    }
}