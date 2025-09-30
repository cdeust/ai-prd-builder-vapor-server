import Foundation
import Vapor

public struct ConsolidatedAnalysisResponseDTO: Content {
    let requestId: String
    let totalMockups: Int
    let analyzedMockups: Int
    let uiElements: [String]
    let userFlows: [UserFlowDTO]
    let businessLogicInferences: [BusinessLogicDTO]
    let extractedText: [String]
    let averageConfidence: Double
}
